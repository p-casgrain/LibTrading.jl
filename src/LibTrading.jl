module LibTrading

export FixSession,
    logon,
    logoff,
    test_request,
    time_update,
    send,
    recv,
    FixField,
    FixMessage,
    FIX_MSG_TYPE_HEARTBEAT,
    FIX_MSG_TYPE_TEST_REQUEST,
    FIX_MSG_TYPE_RESEND_REQUEST,
    FIX_MSG_TYPE_REJECT,
    FIX_MSG_TYPE_SEQUENCE_RESET,
    FIX_MSG_TYPE_LOGOUT,
    FIX_MSG_TYPE_EXECUTION_REPORT,
    FIX_MSG_TYPE_LOGON,
    FIX_MSG_TYPE_NEW_ORDER_SINGLE,
    FIX_MSG_TYPE_SNAPSHOT_REFRESH,
    FIX_MSG_TYPE_INCREMENT_REFRESH,
    FIX_MSG_TYPE_SESSION_STATUS,
    FIX_MSG_TYPE_SECURITY_STATUS,
    FIX_MSG_ORDER_CANCEL_REPLACE,
    FIX_MSG_ORDER_CANCEL_REJECT,
    FIX_MSG_TYPE_MAX,
    FIX_MSG_TYPE_UNKNOWN

using Base.Enums
using Sockets
import Base: pointer, get!

const FIX_SOCKETS = TCPSocket[]

mutable struct FixSession
    pointer::Ptr{Cvoid}
    dialect_name::String
    sender::String
    target::String
    socket::TCPSocket
    fakefd::Cint
    heartbeat::Int

    function FixSession(
        socket::TCPSocket;
        dialect_name::String="fix-4.4",
        sender::String="sender",
        target::String="target",
        heartbeat::Int=15,
    )
        fd = findfirst(isopen, FIX_SOCKETS)
        if !isnothing(fd)
            FIX_SOCKETS[fd] = socket
        else
            push!(FIX_SOCKETS, socket)
            fd = length(FIX_SOCKETS)
        end

        cfg = @ccall "libtrading".fix_session_cfg_new(
            sender::Ptr{Cchar},
            target::Ptr{Cchar},
            heartbeat::Cint,
            dialect_name::Ptr{Cchar},
            fd::Cint,
        )::Ptr{Cvoid}

        ptr = @ccall "libtrading".fix_session_new(cfg::Ptr{Cvoid})::Ptr{Cvoid}


        fix = new(ptr, dialect_name, sender, target, socket, fd, heartbeat)
        finalizer(fix) do sess
            @async Sockets.close(sess.socket)
        end

        return fix
    end
end

#= define and install I/O hooks =#

struct IOVec
    base::Ptr{UInt8}
    len::Csize_t
end

isdefined(Base, :read!) || const read! = read

function io_recv(fd::Cint, buf::Ptr{UInt8}, n::Csize_t, flags::Cint)
    socket = FIX_SOCKETS[fd]
    Sockets.read(socket)
    Base.wait_readnb(socket, 1)
    n = min(n, nb_available(socket.buffer))
    read!(socket.buffer, buf, n)
    return convert(Cssize_t, n)::Cssize_t
end

function io_sendmsg(fd::Cint, iovs::Ptr{IOVec}, n::Csize_t, flags::Cint)
    socket = FIX_SOCKETS[fd]
    len = 0
    for i in 1:n
        iov = unsafe_load(iovs, i)
        write(socket, iov.base, iov.len)
        len += iov.len
    end
    return convert(Cssize_t, len)::Cssize_t
end

unsafe_store!(
    convert(Ptr{Ptr{Cvoid}}, cglobal((:io_recv, :libtrading))),
    @cfunction(io_recv, Cssize_t, (Cint, Ptr{UInt8}, Csize_t, Cint))
)
unsafe_store!(
    convert(Ptr{Ptr{Cvoid}}, cglobal((:io_sendmsg, :libtrading))),
    @cfunction(io_sendmsg, Cssize_t, (Cint, Ptr{IOVec}, Csize_t, Cint))
)

#= fix field tags =#

const FIX_FIELD_TAGS = Dict{Symbol,Cint}(
    :Account => 1,
    :AvgPx => 6,
    :BeginSeqNo => 7,
    :BeginString => 8,
    :BodyLength => 9,
    :CheckSum => 10,
    :ClOrdID => 11,
    :CumQty => 14,
    :EndSeqNo => 16,
    :ExecID => 17,
    :MsgSeqNum => 34,
    :MsgType => 35,
    :NewSeqNo => 36,
    :OrderID => 37,
    :OrderQty => 38,
    :OrdStatus => 39,
    :OrdType => 40,
    :OrigClOrdID => 41,
    :PossDupFlag => 43,
    :Price => 44,
    :RefSeqNum => 45,
    :SecurityID => 48,
    :SenderCompID => 49,
    :SendingTime => 52,
    :Side => 54,
    :Symbol => 55,
    :TargetCompID => 56,
    :Text => 58,
    :TransactTime => 60,
    :RptSeq => 83,
    :EncryptMethod => 98,
    :HeartBtInt => 108,
    :TestReqID => 112,
    :GapFillFlag => 123,
    :ResetSeqNumFlag => 141,
    :ExecType => 150,
    :LeavesQty => 151,
    :MDEntryType => 269,
    :MDEntryPx => 270,
    :MDEntrySize => 271,
    :MDUpdateAction => 279,
    :TradingSessionID => 336,
    :LastMsgSeqNumProcessed => 369,
    :MDPriceLevel => 1023,
)
const FIX_FIELD_TAGS_INV = Dict{Cint,Symbol}(v => k for (k, v) in FIX_FIELD_TAGS)

fix_field_tag(sym::Symbol) = FIX_FIELD_TAGS[sym]
fix_field_tag(sym::String) = FIX_FIELD_TAGS[symbol(sym)]
fix_field_tag(num::Integer) = FIX_FIELD_TAGS_INV[convert(Cint, num)]

#= fix field types =#

@enum FIX_TYPE begin
    FIX_TYPE_INT = 0
    FIX_TYPE_FLOAT = 1
    FIX_TYPE_CHAR = 2
    FIX_TYPE_STRING = 3
    FIX_TYPE_CHECKSUM = 4
    FIX_TYPE_MSGSEQNUM = 5
end

#= fix fields =#

struct FixField # struct fix_field
    tag::Cint      # enum
    typ::Cint      # enum
    val::Int64     # union { int64_t, double, char, char* }
    FixField(tag,typ,val) = new(tag,Int32(typ),val)
end

function FixField(sym::Union{Symbol,String}, val::Char)
    isascii(val) || error("non-ASCII character: $(repr(val))")
    return FixField(fix_field_tag(sym), FIX_TYPE_CHAR, hton(uint64(val)))
end

function FixField(sym::Union{Symbol,String}, val::Integer)
    return FixField(fix_field_tag(sym), FIX_TYPE_INT, val)
end
function FixField(sym::Union{Symbol,String}, val::Float64)
    return FixField(fix_field_tag(sym), FIX_TYPE_FLOAT, reinterpret(Int64, val))
end
FixField(sym::Union{Symbol,String}, val::AbstractFloat) = FixField(sym, float64(val))

const FIX_FIELD_STRINGS = Dict{String,String}()

function FixField(sym::Union{Symbol,String}, val::String)
    val = get!(FIX_FIELD_STRINGS, val, val) # transcode, pin, canonicalize
    return FixField(fix_field_tag(sym), FIX_TYPE_STRING, reinterpret(Int64, pointer(val)))
end


function fix_field_value(fld::FixField)
    (fld.typ == Int(FIX_TYPE_INT)) && return fld.val
    (fld.typ == Int(FIX_TYPE_FLOAT)) && return Float64(fld.val)
    (fld.typ == Int(FIX_TYPE_CHAR)) && return Char(ntoh(fld.val))
    (fld.typ == Int(FIX_TYPE_CHECKSUM)) && return UInt(fld.val)
    (fld.typ == Int(FIX_TYPE_MSGSEQNUM)) && return UInt(fld.val)
    (fld.typ == Int(FIX_TYPE_STRING)) || return "unknown FIX field type: $(fld.typ)"
    p = q = reinterpret(Ptr{UInt8}, fld.val)
    while unsafe_load(q) > 1
        q += 1
    end
    str = unsafe_string(p,q-p)
    return get!(FIX_FIELD_STRINGS, str, str)
end

Base.convert(::Type{String},fld::FixField) = "FixField(", fix_field_tag(fld.tag), ": ", repr(fix_field_value(fld)), ")"


function Base.show(io::IO, fld::FixField)
    return print(
        io, "FixField(", fix_field_tag(fld.tag), ": ", repr(fix_field_value(fld)), ")"
    )
end

#= fix message types =#
@enum FIX_MSG_TYPE begin
    FIX_MSG_TYPE_HEARTBEAT = 0
    FIX_MSG_TYPE_TEST_REQUEST = 1
    FIX_MSG_TYPE_RESEND_REQUEST = 2
    FIX_MSG_TYPE_REJECT = 3
    FIX_MSG_TYPE_SEQUENCE_RESET = 4
    FIX_MSG_TYPE_LOGOUT = 5
    FIX_MSG_TYPE_EXECUTION_REPORT = 6
    FIX_MSG_TYPE_LOGON = 7
    FIX_MSG_TYPE_NEW_ORDER_SINGLE = 8
    FIX_MSG_TYPE_SNAPSHOT_REFRESH = 9
    FIX_MSG_TYPE_INCREMENT_REFRESH = 10
    FIX_MSG_TYPE_SESSION_STATUS = 11
    FIX_MSG_TYPE_SECURITY_STATUS = 12
    FIX_MSG_ORDER_CANCEL_REPLACE = 13
    FIX_MSG_ORDER_CANCEL_REJECT = 14
    FIX_MSG_TYPE_MAX = 15
    FIX_MSG_TYPE_UNKNOWN = -1
end

#= fix messages =#

mutable struct FixMessage
    pointer::Ptr{Cint}
    function FixMessage(msg_type::FIX_MSG_TYPE; kws...)
        msg = new(@ccall "libtrading".fix_message_new()::Ptr{Cint})
        unsafe_store!(msg.pointer, Int32(msg_type))
        finalizer(msg) do x
            @async fix_message_free(x)
        end
        for (k, v) in kws
            push!(msg, FixField(k, v))
        end
        return msg
    end
    FixMessage(p::Ptr) = new(p)
end

function fix_message_free(msg::FixMessage)
    return ccall((:fix_message_free, :libtrading), Cvoid, (Ptr{Cvoid},), msg.pointer)
end

fix_message_type(msg::FixMessage) = unsafe_load(msg.pointer)

#= manipilating fix messages =#

function Base.push!(msg::FixMessage, field::FixField)
    return @ccall "libtrading".fix_message_add_field(msg.pointer::Ptr{Cvoid}, Ref(field)::Ptr{FixField})::Cvoid
end

function Base.length(msg::FixMessage)
    return Int64(ccall((:fix_get_field_count, :libtrading), Cint, (Ptr{Cvoid},), msg.pointer))
end

function Base.getindex(msg::FixMessage, i::Integer)
    1 <= i <= length(msg) || error("invalid field index: $i")
    p = ccall(
        (:fix_get_field_at, :libtrading),
        Ptr{FixField},
        (Ptr{Cvoid}, Cint),
        msg.pointer,
        i - 1,
    )
    return unsafe_load(p)
end

function Base.show(io::IO, msg::FixMessage)
    n = length(msg)
    print(io, "FixMessage type $(fix_message_type(msg) |> FIX_MSG_TYPE) with $n fields")
    for i in 1:length(msg)
        print("\n $i: $(msg[i])")
    end
end

#= fix session API =#

function logon(session::FixSession)
    r = @ccall "libtrading".fix_session_logon(session.pointer::Ptr{Cvoid})::Cint
    r == 0 || error("fix_session_logon failed")
    return nothing
end

function logoff(session::FixSession)
    r = @ccall "libtrading".fix_session_logout(session.pointer::Ptr{Cvoid}, C_NULL::Ptr{UInt8})::Cint
    r == 0 || error("fix_session_logout failed")
    return nothing
end

function test_request(session::FixSession)
    r = @ccall "libtrading".fix_session_test_request(session.pointer::Ptr{Cvoid})::Cint
    r == 0 || error("fix_session_test_request failed")
    return nothing
end

function time_update(session::FixSession)
    r = @ccall "libtrading".fix_session_time_update(session.pointer::Ptr{Cvoid})::Cint
    r == 0 || error("fix_session_time_update failed")
    return nothing
end

function send(session::FixSession, msg::FixMessage, flags::Integer=zero(Cint))
    r = ccall(
        (:fix_session_send, :libtrading),
        Cint,
        (Ptr{Cvoid}, Ptr{Cvoid}, Cint),
        session.pointer,
        msg.pointer,
        flags,
    )
    r >= 0 || error("fix_message_send failed")
    return nothing
end

function recv(session::FixSession, flags::Integer=zero(Cint))
    p = ccall(
        (:fix_session_recv, :libtrading),
        Ptr{Cint},
        (Ptr{Cvoid}, Cint),
        session.pointer,
        flags,
    )
    p != C_NULL || error("no message received")
    return FixMessage(p)
end

end # module
