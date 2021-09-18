using Base.Enums
using DataStructures: OrderedRobinDict, OrderedDict
using Match: @match
import WeakRefStrings

include("./fix_consts.jl")

switch(f, x...) = f(x...)




# FIX Fields
function fix_tag_type(tag::FixTag)::FixFieldType
	@match tag begin
        TAG_CheckSum	            => FIX_TYPE_CHECKSUM
        TAG_LastMsgSeqNumProcesse   => FIX_TYPE_INT
        TAG_MDPriceLevel            => FIX_TYPE_INT
        TAG_BeginSeqNo              => FIX_TYPE_INT
        TAG_RefSeqNum	            => FIX_TYPE_INT
        TAG_EndSeqNo	            => FIX_TYPE_INT
        TAG_NewSeqNo	            => FIX_TYPE_INT
        TAG_RptSeq	                => FIX_TYPE_INT
        TAG_GapFillFlag             => FIX_TYPE_STRING
        TAG_PossDupFlag             => FIX_TYPE_STRING
        TAG_SecurityID              => FIX_TYPE_STRING
        TAG_TestReqID	            => FIX_TYPE_STRING
        TAG_MsgSeqNum	            => FIX_TYPE_MSGSEQNUM
        TAG_MDEntrySize             => FIX_TYPE_FLOAT
        TAG_LastShares              => FIX_TYPE_FLOAT
        TAG_LeavesQty	            => FIX_TYPE_FLOAT
        TAG_MDEntryPx	            => FIX_TYPE_FLOAT
        TAG_OrderQty	            => FIX_TYPE_FLOAT
        TAG_CumQty	                => FIX_TYPE_FLOAT
        TAG_LastPx	                => FIX_TYPE_FLOAT
        TAG_AvgPx	                => FIX_TYPE_FLOAT
        TAG_Price	                => FIX_TYPE_FLOAT
        TAG_TradingSessionID        => FIX_TYPE_STRING
        TAG_MDUpdateAction          => FIX_TYPE_STRING
        TAG_TransactTime            => FIX_TYPE_STRING
        TAG_ExecTransType           => FIX_TYPE_STRING
        TAG_OrigClOrdID             => FIX_TYPE_STRING
        TAG_MDEntryType             => FIX_TYPE_STRING
        TAG_OrdStatus	            => FIX_TYPE_STRING
        TAG_ExecType	            => FIX_TYPE_STRING
        TAG_Password	            => FIX_TYPE_STRING
        TAG_Account	                => FIX_TYPE_STRING
        TAG_ClOrdID	                => FIX_TYPE_STRING
        TAG_OrderID	                => FIX_TYPE_STRING
        TAG_OrdType	                => FIX_TYPE_STRING
        TAG_ExecID	                => FIX_TYPE_STRING
        TAG_Symbol	                => FIX_TYPE_STRING
        TAG_Side	                => FIX_TYPE_STRING
        TAG_Text	                => FIX_TYPE_STRING
        TAG_OrdRejReason            => FIX_TYPE_INT
        TAG_MultiLegReportingTyp    => FIX_TYPE_CHAR
        _			                => FIX_TYPE_STRING	#unrecognized tag - default to string
    end
end

@inline begin Base.parse(type::FixFieldType,val_str::AbstractString)
    return @match type begin
        FIX_TYPE_IN => parse(Int64,val_str)
        FIX_TYPE_FLOAT => parse(Float64,FIX_TYPE_FLOAT)
        FIX_TYPE_CHA => @inbounds val_str[1]
        FIX_TYPE_STRIN => val_str
        FIX_TYPE_CHECKSUM => parse(Int64,val_str)
        FIX_TYPE_MSGSEQNUM => parse(Int64,val_str)
        FIX_TYPE_STRING_8 => val_str # Should change to fixed length string 
        val_str
    end
end

function fix_msg_type_parse(st::AbstractString)

    @match st begin
        "AF" => return FIX_MSG_ORDER_MASS_STATUS_REQUEST
        "CA" => return FIX_MSG_ORDER_MASS_ACTION_REQUEST
        "BZ" => return FIX_MSG_ORDER_MASS_ACTION_REPORT
    end

	@match st[1] begin
        '0' => return FIX_MSG_TYPE_HEARTBEAT
        '1' => return FIX_MSG_TYPE_TEST_REQUEST
        '2' => return FIX_MSG_TYPE_RESEND_REQUEST
        '3' => return FIX_MSG_TYPE_REJECT
        '4' => return FIX_MSG_TYPE_SEQUENCE_RESET
        '5' => return FIX_MSG_TYPE_LOGOUT
        '8' => return FIX_MSG_TYPE_EXECUTION_REPORT
        '9' => return FIX_MSG_ORDER_CANCEL_REJECT
        'A' => return FIX_MSG_TYPE_LOGON
        'D' => return FIX_MSG_TYPE_NEW_ORDER_SINGLE
        'F' => return FIX_MSG_ORDER_CANCEL_REQUEST
        'G' => return FIX_MSG_ORDER_CANCEL_REPLACE
        'W' => return FIX_MSG_TYPE_SNAPSHOT_REFRESH
        'X' => return FIX_MSG_TYPE_INCREMENT_REFRESH
        'h' => return FIX_MSG_TYPE_SESSION_STATUS
        'f' => return FIX_MSG_TYPE_SECURITY_STATUS
        'q' => return FIX_MSG_ORDER_MASS_CANCEL_REQUEST
        'r' => return FIX_MSG_ORDER_MASS_CANCEL_REPORT
        'R' => return FIX_MSG_QUOTE_REQUEST
        'c' => return FIX_MSG_SECURITY_DEFINITION_REQUEST
        's' => return FIX_MSG_NEW_ORDER_CROSS
        'i' => return FIX_MSG_MASS_QUOTE
        'Z' => return FIX_MSG_QUOTE_CANCEL
        'd' => return FIX_MSG_SECURITY_DEFINITION
        'b' => return FIX_MSG_QUOTE_ACKNOWLEDGEMENT
        _   => return FIX_MSG_TYPE_UNKNOWN
    end
end

function fix_field_parse(tag_str,val_str)
    tag = parse(Int64,tag_str) |> FixTag
    fix_field_parse(tag,val_str,fix_tag_type(tag))
end

fix_field_parse(tag::FixTag,val_str,typ::FixFieldType) = FixField(tag,parse(typ,val_str))


struct FixField{T<:Union{Int64,Float64,Char,String}}
	tag::FixTag
    val::T
end

FixField(tag::FixTag,val::T) where {T} = FixField{T}(tag,val)
FixField(p::Union{Pair{FixTag,T},Tuple{FixTag,T}}) where {T} = FixField(first(p),last(p))

Base.first(fld::FixField) = fld.tag
Base.last(fld::FixField) = fld.val
Pair(fld::FixField) = fld.tag => fld.val
Tuple(fld::FixField) = (fld.tag, fld.val)

function Base.print(io::IO,fld::FixField)
    print(io::IO,Int(fld.tag),'=',fld.val)
end

struct FixMessage
	# these are required fields.
    type::FixMessageType
    # TODO: Add the mandatory fields (see Base.write(::FixSession) )

    # this contains the rest of the fields
	fields::Vector{FixField}
    function FixMessage(type::FixMessageType)
        # maybe add sizehint for vector?
        new(type,Vector{FixField}())
    end
end

Base.sizehint!(s::FixMessage, n) = sizehint!(s.fields,n)

function FixMessage(type::FixMessageType,x...)
        new(type,Vector{FixField}(x))
end

Base.push!(msg::FixMessage,fld::FixField) = push!(msg.fields,fld)

function Base.show(io::IO,msg::FixMessage)
    println(io::IO,"FixMessage($type) with fields:")
    for fld in msg.fields
        println(io::IO,'\t',fld)
end
# Base.print(msg::FixMessage)
Base.length(msg::FixMessage) = length(msg.fields)

checksum(io::IOBuffer) = sum(io.data) % 256

function Base.write(session::FixSession,msg::FixMessage)
    # TODO: Add lock argument?
    # TODO: Determine whether clearing necessary?
    # Clear session IO buffers
    take!(session.body_buf)
    take!(session.head_buf)
    
    # Add required tags to body
    join( session.body_buf,
        [ 
            FixField(TAG_SenderCompID,session.sender_comp_id),
            FixField(TAG_TargetCompID,session.target_comp_id),
            FixField(TAG_MsgSeqNum,get_msgseqnum!(session)),
            FixField(TAG_SendingTime,get_sendingtime!(session)) 
        ]
        session.delimiter
        )
    
    # Add main body content
    join( session.body_buf, msg.fields, session.delimiter )

    # Add header info
    print(session.head_buf, FixField(TAG_BeginString, session.begin_string), session.delimiter)
    print(session.head_buf, FixField(TAG_BodyLength, session.body_buf.size), session.delimiter)
    
    # Add checksum info    
    msg_checksum = ( sum(session.head_buf.data) + sum(session.body_buf.data) ) % 256
    print(session.body_buf, FixField(TAG_CheckSum, Int(msg_checksum)), session.delimiter)

    # Write out result to session io
    write(session.io,take!(session.head_buf),take!(session.body_buf))
end


function fix_parse_message(msg_str::AbstractString,delim::Char)
    field_iter = Iterators.enumerate(eachsplit(msg_str,session.delim))
    # Get first field (TAG_BeginString)
    (field_iter,first_field) = Iterators.peel(field_iter)
    # Get second field (TAG_BodyLength)
    (field_iter,second_field) = Iterators.peel(field_iter)
    # Get third field (TAG_BodyLength)
    (field_iter,third_field) = Iterators.peel(field_iter)
    # Initialize Message
    for field_str in eachsplit(field_str,delim)
        tag_str, val_str = split(field_str,'=')
        fix_field_parse(tag_str,val_str)
    end
end