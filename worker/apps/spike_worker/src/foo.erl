-module(foo).
%-behaviour().

-include_lib("eunit/include/eunit.hrl").

-export([ start_link/0, handle_command_msg/1 ]).

start_link() ->
    simple_worker:start_link(?MODULE).

handle_command_msg(Msg) ->
    io:format("Msg Recieved: ~p~n", [Msg]),
    ok.
