import asyncdispatch, json, options
import ../objects, ../constants, ../helpers

proc startThread*(api: RestApi,
        channel_id: string, name: string,
        channel_type = none int, reason = ""): Future[GuildChannel] {.async.} =
    ## Starts a thread without a message.
    let payload = %*{
        "name": name,
        "auto_archive_duration": 1440, # TODO(dannyhpy):
        "type": channel_type,
    }

    result = (await api.request(
        "POST",
        endpointChannelThreads(channel_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc startThread*(api: RestApi, channel_id: string,
        message_id: string, name: string,
        reason = ""): Future[GuildChannel] {.async.} =
    ## Starts a thread with a message.
    let payload = %*{
        "name": name,
        "auto_archive_duration": 1440, # TODO(dannyhpy):
    }

    result = (await api.request(
        "POST",
        endpointMessageThreads(channel_id, message_id),
        $payload,
        audit_reason = reason
    )).newGuildChannel

proc addThreadMember*(api: RestApi, thread_id: string,
        member_id: string) {.async.} =
    ## Adds a thread member.
    discard await api.request(
        "PUT",
        endpointChannelThreadMembers(thread_id) & "/" & member_id,
    )

proc removeThreadMember*(api: RestApi, thread_id: string,
        member_id: string) {.async.} =
    ## Removes a thread member.
    discard await api.request(
        "DELETE",
        endpointChannelThreadMembers(thread_id) & "/" & member_id,
    )

proc joinThread*(api: RestApi, thread_id: string) {.async.} =
    ## Join a thread.
    await api.addThreadMember(thread_id, "@me")

proc leaveThread*(api: RestApi, thread_id: string) {.async.} =
    ## Leave a thread.
    await api.removeThreadMember(thread_id, "@me")

# TODO(dannyhpy): Missing endpoints
#   - List thread members
#   - List active threads
#   - List public archived threads
#   - List private archived threads
#   - List joined private archived threads
