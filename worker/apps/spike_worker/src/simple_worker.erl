-module(simple_worker).
-behaviour(gen_server).

-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record (state, {domain_module,channel}).

start_link(DomainModule) ->
    gen_server:start_link({local, DomainModule}, ?MODULE, [DomainModule], []).

init([DomainModule]) ->
    Queue = <<"add_numbers">>,
    {_Connection, Channel} = create_queue("localhost", Queue),
    io:format(" [*] Waiting for messages. To exit press CTRL+C~n"),
    amqp_channel:subscribe(Channel, #'basic.consume'{queue = Queue, no_ack = true}, self()),
    {ok, #state{domain_module=DomainModule,channel=Channel}}.

handle_call(Msg, From, State) ->
    lager:info("unexpected handle_call(~p, ~p, ~p) -> {reply, ok, ~p}",[Msg,From,State,State]),
    {reply, ok, State}.

handle_cast(Msg, State) ->
    lager:info("unexpected handle_cast(~p, ~p) -> {noreply, ~p}",[Msg,State,State]),
    {noreply, State}.

handle_info(#'basic.consume_ok'{}, State) ->
    lager:info("basic.consume_ok"),
    {noreply, State};
handle_info({#'basic.deliver'{}, #amqp_msg{payload=Body,props=Props}}, State) ->
    ReplyToQueue = Props#'P_basic'.reply_to,
    lager:info("basic.deliver  Body: ~p", [Body]),
    Module = State#state.domain_module,
    Sum = Module:handle_command_msg(Body),
    % amqp_channel:call(State#state.channel, #'queue.declare'{queue = ReplyToQueue}),
    amqp_channel:cast(State#state.channel, #'basic.publish'{routing_key = ReplyToQueue},#'amqp_msg'{payload=Sum}),
    {noreply, State};
handle_info(Info, State) ->
    lager:warning("others  Info: ~p", [Info]),
    {noreply, State}.

terminate(Reason, State) ->
    lager:info("terminate(~p, ~p) -> ok",[Reason,State]),
    ok.

code_change(OldVsn, State, Extra) ->
    lager:info("unexpected code_change(~p, ~p, ~p) -> {ok, ~p}",[OldVsn,State,Extra,State]),
    {ok, State}.

create_queue(Host, Queue) ->
    {ok, Connection} = amqp_connection:start(#amqp_params_network{host = Host}),
    {ok, Channel} = amqp_connection:open_channel(Connection),
    amqp_channel:call(Channel, #'queue.declare'{queue = Queue}),
    {Connection, Channel}.

