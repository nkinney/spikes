-module(foo).
-behaviour(vhx_worker).

-include_lib("eunit/include/eunit.hrl").

-export([ start_link/0, handle_command_msg/1 ]).

start_link() ->
    simple_worker:start_link(?MODULE).

handle_command_msg(Command) ->
    io:format(" [x] Msg Recieved: ~p~n", [Command]),
    Dots = length([C || C <- binary_to_list(Command), C == $.]),
    receive
    after
        Dots * 1000 -> ok
    end,
    io:format(" [x] Done~n"),
    ok.
