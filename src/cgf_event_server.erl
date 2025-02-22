%%% cgf_event_server.erl
%%% vim: ts=3
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @copyright 2025 SigScale Global Inc.
%%% @author Vance Shipley <vances@sigscale.org> [http://www.sigscale.org]
%%% @end
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc This {@link //stdlib/gen_server. gen_server} behaviour callback
%%% 	module provides an event manager in the
%%% 	{@link //cgf. cgf} application.
%%%
-module(cgf_event_server).
-copyright('Copyright (c) 2025 SigScale Global Inc.').
-author('Vance Shipley <vances@sigscale.org>').

-behaviour(gen_server).

% export the gen_server call backs
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
		terminate/2, handle_continue/2, code_change/3]).

-include_lib("kernel/include/logger.hrl").

-record(state, {}).
-type state() :: #state{}.

%%----------------------------------------------------------------------
%%  The gen_server callbacks
%%----------------------------------------------------------------------

-spec init(Args) -> Result
	when
		Args :: [term()],
		Result :: {ok, State :: state()}
				| {ok, State :: state(), Timeout :: timeout() | hibernate | {continue, term()}}
				| {stop, Reason :: term()} | ignore.
%% @see //stdlib/gen_server:init/1
%% @private
init([] = _Args) ->
	State = #state{},
	{ok, State, {continue, init}}.

-spec handle_call(Request, From, State) -> Result
	when
		Request :: term(),
		From :: {pid(), Tag :: any()},
		State :: state(),
		Result :: {reply, Reply :: term(), NewState :: state()}
				| {reply, Reply :: term(), NewState :: state(), timeout() | hibernate | {continue, term()}}
				| {noreply, NewState :: state()}
				| {noreply, NewState :: state(), timeout() | hibernate | {continue, term()}}
				| {stop, Reason :: term(), Reply :: term(), NewState :: state()}
				| {stop, Reason :: term(), NewState :: state()}.
%% @see //stdlib/gen_server:handle_call/3
%% @private
handle_call({file_close = Event, Content} = _Request, _From, State) ->
	case cgf:match_event(Event, Content) of
		{ok, Actions} ->
			{reply, start_action(Event, Content, Actions), State};
		{error, Reason} ->
			?LOG_ERROR([{?MODULE, Reason},
					{event, Event},
					{content, Content}]),
			{reply, {error, Reason}, State}
	end.

-spec handle_cast(Request, State) -> Result
	when
		Request :: term(),
		State :: state(),
		Result :: {noreply, NewState :: state()}
				| {noreply, NewState :: state(), timeout() | hibernate | {continue, term()}}
				| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle a request sent using {@link //stdlib/gen_server:cast/2.
%% 	gen_server:cast/2} or {@link //stdlib/gen_server:abcast/2.
%% 	gen_server:abcast/2,3}.
%% @@see //stdlib/gen_server:handle_cast/2
%% @private
handle_cast(_Request, State) ->
	{noreply, State}.

-spec handle_continue(Continue, State) -> Result
	when
		Continue :: term(),
		State :: state(),
		Result :: {noreply, NewState :: state()}
				| {noreply, NewState :: state(), timeout() | hibernate | {continue, term()}}
				| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle continued execution.
handle_continue(init = _Continue, State) ->
	case cgf_event:add_handler(cgf_event, []) of
		ok ->
			{noreply, State};
		{error, Reason} ->
			{stop, Reason, State};
		{'EXIT', Reason} ->
			{stop, Reason, State}
	end.

-spec handle_info(Info, State) -> Result
	when
		Info :: timeout | term(),
		State :: state(),
		Result :: {noreply, NewState :: state()}
				| {noreply, NewState :: state(), timeout() | hibernate | {continue, term()}}
				| {stop, Reason :: term(), NewState :: state()}.
%% @doc Handle a received message.
%% @@see //stdlib/gen_server:handle_info/2
%% @private
handle_info({gen_event_EXIT, _Handler, Reason} = _Info, State) ->
	{stop, Reason, State}.

-spec terminate(Reason, State) -> any()
	when
		Reason :: normal | shutdown | {shutdown, term()} | term(),
      State :: state().
%% @see //stdlib/gen_server:terminate/3
%% @private
terminate(_Reason, _State) ->
	ok.

-spec code_change(OldVersion, State, Extra) -> Result
	when
		OldVersion :: term() | {down, term()},
		State :: state(),
		Extra :: term(),
		Result :: {ok, NewState :: state()} | {error, Reason :: term()}.
%% @see //stdlib/gen_server:code_change/3
%% @private
code_change(_OldVersion, State, _Extra) ->
	{ok, State}.

%%----------------------------------------------------------------------
%%  The cgf_event_server private API
%%----------------------------------------------------------------------

%% @hidden
start_action(Event, #{root := Root,
		path := <<$/, Path/binary>>} = Content, Actions)
		when byte_size(Root) > 0 ->
	start_action(Event, Content#{path := Path}, Actions);
start_action(Event, #{root := Root, path := Path} = Content,
		[{Match, {Module, Log} = Action} | T]) ->
	Filename = filename:join(Root, Path),
	StartArgs = [Module, [Filename, Log], []],
	start_action1(Event, Content, Match, Action, T, StartArgs);
start_action(Event, #{root := Root, path := Path} = Content,
		[{Match, {Module, Log, Metadata} = Action} | T]) ->
	Filename = filename:join(Root, Path),
	StartArgs = [Module, [Filename, Log, Metadata], []],
	start_action1(Event, Content, Match, Action, T, StartArgs);
start_action(Event, #{root := Root, path := Path} = Content,
		[{Match, {Module, Log, Metadata, ExtraArgs} = Action} | T]) ->
	Filename = filename:join(Root, Path),
	StartArgs = [Module, [Filename, Log, Metadata] ++ ExtraArgs, []],
	start_action1(Event, Content, Match, Action, T, StartArgs);
start_action(Event, #{root := Root, path := Path} = Content,
		[{Match, {Module, Log, Metadata, ExtraArgs, Opts} = Action} | T]) ->
	Filename = filename:join(Root, Path),
	StartArgs = [Module, [Filename, Log, Metadata] ++ ExtraArgs, Opts],
	start_action1(Event, Content, Match, Action, T, StartArgs);
start_action(_Event, _Content, []) ->
	ok.
%% @hidden
start_action1(Event, Content, Match, Action, T, StartArgs) ->
	case supervisor:start_child(cgf_import_sup, StartArgs) of
		{ok, _Child} ->
			ok;
		{ok, _Child, _Info} ->
			ok;
		{error, Reason} ->
			?LOG_ERROR([{?MODULE, Reason},
					{event, Event},
					{content, Content},
					{match, Match},
					{action, Action}])
	end,
	start_action(Event, Content, T).

