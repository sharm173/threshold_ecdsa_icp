import Float "mo:base/Float";

module Types {

    public type Quote = {
        quoteId : Text;
        routeId : Text;
        counterpartyId : Text;
        rate : Text;
        sourceTokenAddress : Text;
        sourceChainId : Int;
        destinationTokenDenom : Text;
        destinationChainId : Text;
        sourceAmount : Text;
        destinationAmount : Text;
        buyerSourceAddress : Text;
        buyerDestinationAddress : Text;
        subvaultId : Text;
        expiration : Int;
        priority : Int;
        paymaster : Int;
        messageHash : Text;
        signature : Text;
        status : Text;
    };

    public type Params = {
        quoteId : Text;
        subvaultId : Text;
        amount : Text;
        transactionHash : Text;
        contractAddress : Text;
        apiKey : Text;
    };

    public type TransactionReceipt = {
        jsonrpc : Text;
        id : Int;
        result : {
            blockHash : Text;
            blockNumber : Text;
            contractAddress : ?Text;
            cumulativeGasUsed : Text;
            effectiveGasPrice : Text;
            from : Text;
            gasUsed : Text;
            logs : [{
                transactionHash : Text;
                address : Text;
                blockHash : Text;
                blockNumber : Text;
                data : Text;
                logIndex : Text;
                removed : Bool;
                topics : [Text];
                transactionIndex : Text;
            }];
            logsBloom : Text;
            root : ?Text;
            status : ?Text;
            to : Text;
            transactionHash : Text;
            transactionIndex : Text;
            type_ : Text;
        };
    };

    public type Timestamp = Nat64;

    //1. Type that describes the Request arguments for an HTTPS outcall
    //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
    public type HttpRequestArgs = {
        url : Text;
        max_response_bytes : ?Nat64;
        headers : [HttpHeader];
        body : ?[Nat8];
        method : HttpMethod;
        transform : ?TransformRawResponseFunction;
    };

    public type HttpHeader = {
        name : Text;
        value : Text;
    };

    public type HttpMethod = {
        #get;
        #post;
        #head;
    };

    public type HttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    //2. HTTPS outcalls have an optional "transform" key. These two types help describe it.
    //"The transform function may, for example, transform the body in any way, add or remove headers,
    //modify headers, etc. "
    //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request

    //2.1 This type describes a function called "TransformRawResponse" used in line 14 above
    //"If provided, the calling canister itself must export this function."
    //In this minimal example for a `GET` request, we declare the type for completeness, but
    //we do not use this function. We will pass "null" to the HTTP request.
    public type TransformRawResponseFunction = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    //2.2 These types describes the arguments the transform function needs
    public type TransformArgs = {
        response : HttpResponsePayload;
        context : Blob;
    };

    public type CanisterHttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    public type TransformContext = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    //3. Declaring the IC management canister which we use to make the HTTPS outcall
    public type IC = actor {
        http_request : HttpRequestArgs -> async HttpResponsePayload;
    };

};
