-module(epgsql_decimal).
-behaviour(epgsql_codec).

-include_lib("epgsql/include/protocol.hrl").
-include_lib("decimal/include/decimal.hrl").

%% Behaviour callbacks
-export([
    init/2,
    names/0,
    decode/3,
    encode/3
]).

-define(NBASE, 10000).
-define(NDIGITS, 4).
-define(NPOS, 0).     %% #0x0000
-define(NNEG, 16384). %% #0x4000

%% =============================================================================
%% Behaviour callbacks
%% =============================================================================

init(_Opts, _Sock) -> undefined.

names() ->
    [
     numeric
    ].

decode(Binary, numeric, _State) ->
    decode_numeric(Binary).

encode(Decimal, numeric, _State) when ?is_decimal(Decimal) ->
    encode_numeric(Decimal);
encode(Other, numeric, _State) ->
    encode_numeric(?to_decimal(Other)).

%% =============================================================================
%% Internal functions
%% =============================================================================

encode_numeric(Decimal) ->
    {Base, Exponent} = align(Decimal),
    case Base < 0 of
        true ->
            Sign = ?NNEG,
            AbsBase = -Base;
        false ->
            Sign = ?NPOS,
            AbsBase = Base
    end,
    Digits = to_digits(AbsBase),
    encode_numeric(Sign, Digits, Exponent).

align(Decimal) ->
    {Base, Exponent} = decimal:reduce(Decimal),
    Shift = case (abs(Exponent) rem ?NDIGITS) of
        0 -> 0;
        Diff when Exponent < 0 -> ?NDIGITS - Diff;
        Diff -> Diff
    end,
    {Base * trunc(math:pow(10, Shift)), Exponent-Shift}.

encode_numeric(Sign, Digits, Exponent) ->
    NDigits = length(Digits),
    Dscale = max(-Exponent, 0),
    Weight = (NDigits - 1) + (Exponent div ?NDIGITS),
    BinaryDigits = << <<D:?int16>> || D <- Digits >>,
    <<NDigits:?int16, Weight:?int16, Sign:?int16, Dscale:?int16, BinaryDigits/binary>>.

to_digits(Number) -> to_digits(Number, []).
to_digits(0, Acc) -> Acc;
to_digits(Number, Acc) ->
    D1 = Number rem ?NBASE,
    Rest = Number div ?NBASE,
    to_digits(Rest, [D1|Acc]).

decode_numeric(N) when is_binary(N) ->
    <<NDigits:?int16, Weight:?int16, Sign:?int16, _Dscale:?int16, Rest/binary>> = N,
    Base = lists:foldl(fun(A, Acc) ->
        Acc*?NBASE + A
    end, 0, [Num || <<Num:1/big-signed-unit:16>> <= Rest]),
    BaseR = case Sign of
        ?NNEG -> -Base;
        ?NPOS -> Base
    end,
    Exponent = -(NDigits - Weight - 1) * ?NDIGITS,
    decimal:reduce({BaseR, Exponent}).
