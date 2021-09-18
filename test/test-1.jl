using Revise
using Sockets

push!(Base.Libc.Libdl.DL_LOAD_PATH, "/Users/pcasgrain/lib/")
includet("./src/LibTrading.jl")
using .LibTrading

@async begin
    server = listen(2000)
    while true
        sock = accept(server)
        @async while isopen(sock)
            mystr = String(readline(sock; keep=true))
            println(stdout,mystr)
            write(sock,mystr)
        end
    end
end

mysock = Sockets.connect(2000)
mysess = FixSession(mysock)

logon(mysess)


req = FixMessage(
    FIX_MSG_TYPE_NEW_ORDER_SINGLE;
    TransactTime="54191923311431120",
    ClOrdID="ClOrdID",
    Symbol="Symbol",
    OrderQty=100,
    OrdType="2",
    Side="1",
    Price=100,
)

LibTrading.send(mysess, req)
LibTrading.recv(mysess)






@async begin
           server = listen(4001)
           while true
               sock = accept(server)
               @async while isopen(sock)
                   write(sock, readline(sock, keep=true))
               end
           end
       end

clientside = connect(4001)
@async while isopen(clientside)
           write(stdout, readline(clientside, keep=true))
       end
