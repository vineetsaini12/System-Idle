#!/usr/bin/env escript

main(_) ->
    net_kernel:start([shell, shortnames]),
    erlang:set_cookie(node(), butler_server),

       %% Perform data sanity checks
    io:format("~nData Sanity Check 1: "),
    DataSanityCheck1 = rpc:call(butler_server@localhost, mhs_api_utils, run_data_domain_and_sanity_checks, [true]),
    io:format("~p~n", [DataSanityCheck1]),

    io:format("~nData Sanity Check 2: "),
    DataSanityCheck2 = rpc:call(butler_server@localhost, data_domain_validation_functions, validate_all_tables, [true]),
    io:format("~p~n", [DataSanityCheck2]),



    {ActiveStation,ActivePutOutputs, InevntoryawaitedOrders, PendingOrders, CreatedOrders,
     InprogessAudits, PendingapprovalAudits, PausedAudits, CreatedAudits,
     ActiveAuditLines, ActivePickInstructions, ClosePPSStation,
     PendingPPSTasks, PendingAuditTasks, PendingPostpickTasks, PendingMoveTasks,
     NotToteinbin, RackStorable,PickBins,PutBins,ActivePutOutputsStatus,
     InevntoryawaitedOrdersStatus,PendingOrdersStatus,CreatedOrdersStatus,
     InprogessAuditsStatus,PendingapprovalAuditsStatus,PausedAuditsStatus,
     CreatedAuditsStatus,ActiveAuditLinesStatus,ActivePickInstructionsStatus,
     PendingPPSTasksStatus,PendingAuditTasksStatus,PendingPostpickTasksStatus,
     PendingMoveTasksStatus,NotToteinbinStatus,PickBinsStatus,PutBinsStatus,ActiveStationStatus,ClosePPSStationStatus,Butler,Rack} = fetch_data(),

    %% Save data to files
    save_data_to_file("ACTIVE-STATIONS", length(ActiveStation),ActiveStation,ActiveStationStatus),
    save_data_to_file("CLOSED-STATIONS",length(ClosePPSStation),ClosePPSStation,ClosePPSStationStatus),
    save_data_to_file("PICK-BINS", length(PickBins), PickBins,PickBinsStatus),
    save_data_to_file("PUT-BINS", length(PutBins), PutBins,PutBinsStatus),
    save_data_to_file("TOTES-ATTACHED-BINS", length(NotToteinbin), NotToteinbin,NotToteinbinStatus),
    save_data_to_file("PENDING-ORDERS", length(PendingOrders), PendingOrders,PendingOrdersStatus),
    save_data_to_file("INVENTORY-AWAITED-ORDERS", length(InevntoryawaitedOrders), InevntoryawaitedOrders,InevntoryawaitedOrdersStatus),
    save_data_to_file("CREATED-ORDERS", length(CreatedOrders), CreatedOrders,CreatedOrdersStatus),
    save_data_to_file("PUT-OUTPUTS", length(ActivePutOutputs), ActivePutOutputs,ActivePutOutputsStatus),
    save_data_to_file("PICK-INSTRUCTIONS", length(ActivePickInstructions),ActivePickInstructions,ActivePickInstructionsStatus),
    save_data_to_file("IN-PROGRESS-AUDITS", length(InprogessAudits), InprogessAudits,InprogessAuditsStatus),
    save_data_to_file("PENDING-APPROVAL-AUDITS", length(PendingapprovalAudits),PendingapprovalAudits,PendingapprovalAuditsStatus),
    save_data_to_file("PAUSED-AUDITS", length(PausedAudits), PausedAudits,PausedAuditsStatus),
    save_data_to_file("CREATED-AUDITS", length(CreatedAudits), CreatedAudits,CreatedAuditsStatus),
    save_data_to_file("PENDING-AUDIT-LINES", length(ActiveAuditLines), ActiveAuditLines, ActiveAuditLinesStatus),
    save_data_to_file("PPS-TASKS", length(PendingPPSTasks), PendingPPSTasks,PendingPPSTasksStatus),
    save_data_to_file("AUDIT-TASKS", length(PendingAuditTasks), PendingAuditTasks,PendingAuditTasksStatus),
    save_data_to_file("POST-PICK-TASKS", length(PendingPostpickTasks), PendingPostpickTasks,PendingPostpickTasksStatus),
    save_data_to_file("MOVE-TASKS", length(PendingMoveTasks), PendingMoveTasks,PendingMoveTasksStatus),
    save_data_to_file("RACK-STORABLE", length(RackStorable), RackStorable),
    save_data_to_file("DataSanity-MHS", DataSanityCheck1),
    save_data_to_file("DataSanity-DOMAIN", DataSanityCheck2),
    save_data_to_file("PPS-QUEUE-BUTLERS",length(Butler),Butler),
    save_data_to_file("PPS-QUEUE-RACKS",length(Rack),Rack),


 
    %% Fetch all scheduled jobs and save them to a text file
    case rpc:call(butler_server@localhost, erlcron, get_all_jobs, []) of
        List when is_list(List) ->
            JobCount = length(List),
            file:write_file("/home/gor/SystemIdle/texts/SCHEDULED-JOBS",
                            iolist_to_binary(io_lib:format("Scheduled Jobs Count: ~p~nScheduled Jobs: ~p~n", [JobCount, List]))),
            io:format("Scheduled Jobs Count: ~p (Saved to Scheduled_Jobs)~n", [JobCount]);
        Error ->
            file:write_file("/home/gor/SystemIdle/texts/SCHEDULED-JOBS", "Failed to fetch scheduled jobs\n")
    end.

%% Function to fetch data
fetch_data() ->
    {ok, AllPPSList} = rpc:call(butler_server@localhost, ppsnode, get_all, [key]),
    %io:format("PPS List: ~p~n", [AllPPSList]),
    
    % Fetch filtered PPS list
    FilteredPPSList = case catch rpc:call(butler_server@localhost, ud_put_manager, get_ud_put_pps, []) of
        {'EXIT', _} -> ok;
        {badrpc, Reason} -> ok;
        PPSList when is_list(PPSList) -> [ PPS || {PPS, Type} <- PPSList, Type =/= ud_put_manual]
    end,
    
    % Compute the final PPS list (AllPPSList - FilteredPPSList)
    FinalPPSList = lists:subtract(AllPPSList, FilteredPPSList),
    io:format("Final PPS List: ~p~n", [FinalPPSList]),
        
    {ok,ClosePPSStation} = rpc:call(butler_server@localhost, ppsnode, search_by, [[{status, in, [close, force_close]}], key]),
    ActiveStation=lists:subtract(FinalPPSList,ClosePPSStation),
    ActiveStationStatus=get_status_and_distinct(butler_server@localhost,ppsnode,search_by , [[{pps_id ,in,ActiveStation}],[status]]),
    ClosePPSStationStatus=get_status_and_distinct(butler_server@localhost, ppsnode, search_by, [[{status, in, [close, force_close]}], [status]]),
    ActivePutOutputsStatus=get_status_and_distinct(butler_server@localhost, put_output1, search_by, [[{status, notequal, completed}],[status]]),
    InevntoryawaitedOrdersStatus=get_status_and_distinct(butler_server@localhost, order_node, search_by, [[{status, in, [inventory_awaited, temporary_unfulfillable]}],[status]]),
    PendingOrdersStatus=get_status_and_distinct(butler_server@localhost, order_node, search_by, [[{status, in, [pending, {pending, modified}]}],[status]]),
    CreatedOrdersStatus=get_status_and_distinct(butler_server@localhost, order_node, search_by, [[{status, equal, created}],[status]]),
    InprogessAuditsStatus=get_status_and_distinct(butler_server@localhost, auditrec, search_by, [[{status, in, [audit_tasked, audit_pending, audit_conflicting]}],[status]]),
    PendingapprovalAuditsStatus=get_status_and_distinct(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_pending_approval}],[status]]),
    PausedAuditsStatus=get_status_and_distinct(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_paused}],[status]]),
    CreatedAuditsStatus=get_status_and_distinct(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_created}],[status]]),
    ActiveAuditLinesStatus = get_status_and_distinct(butler_server@localhost, auditlinerec1, search_by, [[{status, notin, [audit_completed, audit_resolved, audit_reaudited, audit_cancelled, audit_created]}], [status]]),
    ActivePickInstructionsStatus=get_status_and_distinct(butler_server@localhost, pick_instruction, search_by, [[{status, notequal, complete}],[status]]),
    PendingPPSTasksStatus=get_status_and_distinct(butler_server@localhost, ppstaskrec, search_by, [[{status, notequal, complete}],[status]]),
    PendingAuditTasksStatus=get_status_and_distinct(butler_server@localhost, audittaskrec, search_by, [[{status, notequal, complete}],[status]]),
    PendingPostpickTasksStatus=get_status_and_distinct(butler_server@localhost, postpicktaskrec, search_by, [[{status, notequal, complete}],[status]]),
    PendingMoveTasksStatus=get_status_and_distinct(butler_server@localhost, movetaskrec, search_by, [[{status, notequal, complete}],[status]]),
    NotToteinbinStatus=get_status_and_distinct(butler_server@localhost, ppsbinrec, search_by, [[{totes_associated, notequal, []}], [status]]),
    PickBinsStatus=get_status_and_distinct(butler_server@localhost, ppsbinrec, search_by, [[{status,in,[in_use,order_front_complete,pick_processed]}], [status]]),
    PutBinsStatus=get_status_and_distinct(butler_server@localhost, ppsbinrec, search_by, [[{status,in,[staged,complete]}], [status]]),


    
    {ok,Gridinfo}=rpc:call(butler_server@localhost,gridinfo,search_by,[[{attribute,in,[pps_exit_queue,pps,pps_entry_queue]}],key]),
    {ok,Butler}=rpc:call(butler_server@localhost,butlerinfo,search_by,[[{position,in,Gridinfo}],key]),
    {ok,Rack}=rpc:call(butler_server@localhost,rackinfo,search_by,[[{position,in,Gridinfo}],key]),
    {ok,ActivePutOutputs} = rpc:call(butler_server@localhost, put_output1, search_by, [[{status, notequal, completed}], key]),
    {ok,InevntoryawaitedOrders} = rpc:call(butler_server@localhost, order_node, search_by, [[{status, in, [inventory_awaited, temporary_unfulfillable]}], key]),
    {ok,PendingOrders} = rpc:call(butler_server@localhost, order_node, search_by, [[{status, in, [pending, {pending, modified}]}], key]),
    {ok,CreatedOrders} = rpc:call(butler_server@localhost, order_node, search_by, [[{status, equal, created}], key]),
    {ok,InprogessAudits} = rpc:call(butler_server@localhost, auditrec, search_by, [[{status, in, [audit_tasked, audit_pending, audit_conflicting]}], key]),
    {ok,PendingapprovalAudits} = rpc:call(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_pending_approval}], key]),
    {ok,PausedAudits} = rpc:call(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_paused}], key]),
    {ok,CreatedAudits} = rpc:call(butler_server@localhost, auditrec, search_by, [[{status, equal, audit_created}], key]),
    {ok,ActiveAuditLines} = rpc:call(butler_server@localhost, auditlinerec1, search_by, [[{status, notin, [audit_completed, audit_resolved, audit_reaudited, audit_cancelled, audit_created]}], key]),
    {ok,ActivePickInstructions} = rpc:call(butler_server@localhost, pick_instruction, search_by, [[{status, notequal, complete}], key]),
    {ok,PendingPPSTasks} = rpc:call(butler_server@localhost, ppstaskrec, search_by, [[{status, notequal, complete}], key]),
    {ok,PendingAuditTasks} = rpc:call(butler_server@localhost, audittaskrec, search_by, [[{status, notequal, complete}], key]),
    {ok,PendingPostpickTasks} = rpc:call(butler_server@localhost, postpicktaskrec, search_by, [[{status, notequal, complete}], key]),
    {ok,PendingMoveTasks} = rpc:call(butler_server@localhost, movetaskrec, search_by, [[{status, notequal, complete}], key]),
    {ok,NotToteinbin} = rpc:call(butler_server@localhost, ppsbinrec, search_by, [[{totes_associated, notequal, []}], [bin_info, totes_associated]]),
    {ok,RackStorable} = rpc:call(butler_server@localhost, rackinfo, search_by, [[{is_stored, notequal, true}], key]),
    {ok, PickBins} = rpc:call(butler_server@localhost, ppsbinrec, search_by, [[{status,in,[in_use,order_front_complete,pick_processed]}], [bin_info,status]]),
    {ok, PutBins} = rpc:call(butler_server@localhost, ppsbinrec, search_by, [[{status,in,[staged,complete]}], [bin_info,status]]),


    {ActiveStation,ActivePutOutputs, InevntoryawaitedOrders, PendingOrders, CreatedOrders,
     InprogessAudits, PendingapprovalAudits, PausedAudits, CreatedAudits,
     ActiveAuditLines, ActivePickInstructions, ClosePPSStation,
     PendingPPSTasks, PendingAuditTasks, PendingPostpickTasks, PendingMoveTasks,
     NotToteinbin, RackStorable,PickBins,PutBins,ActivePutOutputsStatus,
     InevntoryawaitedOrdersStatus,PendingOrdersStatus,CreatedOrdersStatus,
     InprogessAuditsStatus,PendingapprovalAuditsStatus,PausedAuditsStatus,
     CreatedAuditsStatus,ActiveAuditLinesStatus,ActivePickInstructionsStatus,
     PendingPPSTasksStatus,PendingAuditTasksStatus,PendingPostpickTasksStatus,
     PendingMoveTasksStatus,NotToteinbinStatus,PickBinsStatus,PutBinsStatus,ActiveStationStatus,ClosePPSStationStatus,Butler,Rack}.

%% Function to save count + values to a file
save_data_to_file(Filename, Count, Data) ->
    Content = io_lib:format("Count = ~p~nData = ~p~n", [Count, Data]),
    FilePath = "/home/gor/SystemIdle/texts/" ++ Filename,
    file:write_file(FilePath, iolist_to_binary(Content)).

save_data_to_file(Filename, Data) ->
    Content = io_lib:format("Data = ~p~n", [Data]),
    FilePath = "/home/gor/SystemIdle/texts/" ++ Filename,
    file:write_file(FilePath, iolist_to_binary(Content)).

save_data_to_file(Filename, Count, Data, Status) ->
    Content = io_lib:format("Count = ~p~nStatus = ~p~nData = ~p~n", [Count, Status, Data]),
    FilePath = "/home/gor/SystemIdle/texts/" ++ Filename,
    file:write_file(FilePath, iolist_to_binary(Content)).

get_status_and_distinct(Node, Module, Function, Args) ->
    {ok, Data} = rpc:call(Node, Module, Function, Args),
    Status = lists:usort(lists:flatten(Data)),
    Status.
