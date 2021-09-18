
# Define message types
@enum FixMessageType::Int64 begin
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
    FIX_MSG_ORDER_CANCEL_REQUEST = 15
    FIX_MSG_ORDER_MASS_CANCEL_REQUEST = 16
    FIX_MSG_ORDER_MASS_CANCEL_REPORT = 17
    FIX_MSG_QUOTE_REQUEST = 18
    FIX_MSG_SECURITY_DEFINITION_REQUEST = 19
    FIX_MSG_NEW_ORDER_CROSS = 20
    FIX_MSG_MASS_QUOTE = 21
    FIX_MSG_QUOTE_CANCEL = 22
    FIX_MSG_SECURITY_DEFINITION = 23
    FIX_MSG_QUOTE_ACKNOWLEDGEMENT = 24
    FIX_MSG_ORDER_MASS_STATUS_REQUEST = 25
    FIX_MSG_ORDER_MASS_ACTION_REQUEST = 26
    FIX_MSG_ORDER_MASS_ACTION_REPORT = 27
    FIX_MSG_TYPE_MAX # NON-API
    FIX_MSG_TYPE_UNKNOWN = typemax(UInt32) # ~0UL
end

## Some Constants
const FIX_MAX_HEAD_LEN = UInt32(256)
const FIX_MAX_BODY_LEN = UInt32(1024)
const FIX_MAX_MESSAGE_SIZE = (FIX_MAX_HEAD_LEN + FIX_MAX_BODY_LEN)

# Total number of elements of fix_tag type
const FIX_MAX_FIELD_NUMBER = 48

const FIX_MSG_STATE_PARTIAL = 1
const FIX_MSG_STATE_GARBLED = 2

@enum FixTag begin
    TAG_Account = 1
    TAG_AvgPx = 6
    TAG_BeginSeqNo = 7
    TAG_BeginString = 8
    TAG_BodyLength = 9
    TAG_CheckSum = 10
    TAG_ClOrdID = 11
    TAG_CumQty = 14
    TAG_EndSeqNo = 16
    TAG_ExecID = 17
    TAG_ExecTransType = 20
    TAG_LastPx = 31
    TAG_LastShares = 32
    TAG_MsgSeqNum = 34
    TAG_MsgType = 35
    TAG_NewSeqNo = 36
    TAG_OrderID = 37
    TAG_OrderQty = 38
    TAG_OrdStatus = 39
    TAG_OrdType = 40
    TAG_OrigClOrdID = 41
    TAG_PossDupFlag = 43
    TAG_Price = 44
    TAG_RefSeqNum = 45
    TAG_SecurityID = 48
    TAG_SenderCompID = 49
    TAG_SendingTime = 52
    TAG_Side = 54
    TAG_Symbol = 55
    TAG_TargetCompID = 56
    TAG_Text = 58
    TAG_TransactTime = 60
    TAG_RptSeq = 83
    TAG_EncryptMethod = 98
    TAG_CXlRejReason = 102
    TAG_OrdRejReason = 103
    TAG_HeartBtInt = 108
    TAG_TestReqID = 112
    TAG_GapFillFlag = 123
    TAG_ResetSeqNumFlag = 141
    TAG_ExecType = 150
    TAG_LeavesQty = 151
    TAG_MDEntryType = 269
    TAG_MDEntryPx = 270
    TAG_MDEntrySize = 271
    TAG_MDUpdateAction = 279
    TAG_TradingSessionI = 336
    TAG_LastMsgSeqNumProcesse = 369
    TAG_MultiLegReportingTyp = 442
    TAG_Password = 554
    TAG_MDPriceLevel = 1023
end


@enum FixFieldType begin
    FIX_TYPE_INT
    FIX_TYPE_FLOAT
    FIX_TYPE_CHAR
    FIX_TYPE_STRING
    FIX_TYPE_CHECKSUM
    FIX_TYPE_MSGSEQNUM
    FIX_TYPE_STRING_8 # Should change to fixed length string
end


