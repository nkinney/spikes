-module(vhx_worker).

-callback handle_command_msg(Command :: binary()) -> 'ok'.
