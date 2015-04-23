-module(foo).
-behaviour(vhx_worker).

-include_lib("eunit/include/eunit.hrl").

-export([ start_link/0, handle_command_msg/1 ]).

start_link() ->
    simple_worker:start_link(?MODULE).

handle_command_msg(Body) ->
    lager:info(" [x] Msg Recieved: ~p", [Body]),
    {struct,PropList} = mochijson2:decode(Body),
    NumbersToAdd = proplists:get_value(<<"params">>,PropList),
    Sum = ensure_binary(mochijson2:encode([ok,lists:sum(NumbersToAdd)])),
    lager:info(" [x] Msg Reply: ~p", [Sum]),
    Sum.

ensure_binary(B) when is_binary(B) ->
	B;
ensure_binary(B) when is_list(B) ->
	list_to_binary(B).