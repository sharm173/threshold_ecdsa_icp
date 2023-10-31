import Blob "mo:base/Blob";
import Cycles "mo:base/ExperimentalCycles";
import Debug "mo:base/Debug";
import Error "mo:base/Error";
import Hex "./utils/Hex";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Prim "mo:prim";
import Principal "mo:base/Principal";
import SHA256 "./utils/SHA256";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Float "mo:base/Float";
import Types "Types";
import { JSON } "mo:serde";

actor {
  type IC = actor {
    ecdsa_public_key : ({
      canister_id : ?Principal;
      derivation_path : [Blob];
      key_id : { curve : { #secp256k1 }; name : Text };
    }) -> async ({ public_key : Blob; chain_code : Blob });
    sign_with_ecdsa : ({
      message_hash : Blob;
      derivation_path : [Blob];
      key_id : { curve : { #secp256k1 }; name : Text };
    }) -> async ({ signature : Blob });
    http_request : Types.HttpRequestArgs -> async Types.HttpResponsePayload;
  };

  let ic : IC = actor ("aaaaa-aa");

  public shared (msg) func public_key() : async {
    #Ok : { public_key_hex : Text };
    #Err : Text;
  } {
    let caller = Principal.toBlob(msg.caller);
    try {
      let { public_key } = await ic.ecdsa_public_key({
        canister_id = null;
        derivation_path = [caller];
        key_id = { curve = #secp256k1; name = "test_key_1" };
      });
      #Ok({ public_key_hex = Hex.encode(Blob.toArray(public_key)) });
    } catch (err) {
      #Err(Error.message(err));
    };
  };

  public query func transform(raw : Types.TransformArgs) : async Types.CanisterHttpResponsePayload {
    let transformed : Types.CanisterHttpResponsePayload = {
      status = raw.response.status;
      body = raw.response.body;
      headers = [
        {
          name = "Content-Security-Policy";
          value = "default-src 'self'";
        },
        { name = "Referrer-Policy"; value = "strict-origin" },
        { name = "Permissions-Policy"; value = "geolocation=(self)" },
        {
          name = "Strict-Transport-Security";
          value = "max-age=63072000";
        },
        { name = "X-Frame-Options"; value = "DENY" },
        { name = "X-Content-Type-Options"; value = "nosniff" },
      ];
    };
    transformed;
  };

  private func getQuote(quoteId : Text) : async ?Types.Quote {
    let url = "https://client.starta-testnet.com/verified-quote?quoteId=" # quoteId;
    let host : Text = "client.starta-testnet.com";

    let request_headers = [
      { name = "Host"; value = host # ":443" },
      { name = "User-Agent"; value = "exchange_rate_canister" },
    ];

    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Types.HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      body = null; //optional for request
      method = #get;
      transform = ?transform_context;
    };

    Cycles.add(20_949_972_000);

    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

    let response_body : Blob = Blob.fromArray(http_response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };

    Debug.print(decoded_text);
    try {
      let #ok(blob) = JSON.fromText(decoded_text, null);
      let quote : ?Types.Quote = from_candid (blob);

      Debug.print("JSON CONVERTED");

      quote;
    } catch (err) {
      Debug.print("ERROR");
      Debug.print(Error.message(err));
      null;
    };

  };

  private func getTransactionReceipt(transactionHash : Text) : async ?Types.TransactionReceipt {
    let url = "https://eth-sepolia.g.alchemy.com/v2/41sO1jh88HCM_be7V1BTLDIyz3k_kzuP";
    let host : Text = "eth-sepolia.g.alchemy.com";

    // let idempotency_key : Text = generateUUID();

    let request_headers = [
      { name = "Host"; value = host # ":443" },
      { name = "User-Agent"; value = "http_post_sample" }, //edit
      { name = "Content-Type"; value = "application/json" },
      //  { name = "Idempotency-Key"; value = idempotency_key },
    ];

    let request_body_json : Text = "{ \"method\": \"eth_getTransactionReceipt\",\"params\": [\"" # transactionHash # "\"],\"id\": 1,\"jsonrpc\": \"2.0\" }";
    let request_body_as_Blob : Blob = Text.encodeUtf8(request_body_json);
    let request_body_as_nat8 : [Nat8] = Blob.toArray(request_body_as_Blob);

    let transform_context : Types.TransformContext = {
      function = transform;
      context = Blob.fromArray([]);
    };

    let http_request : Types.HttpRequestArgs = {
      url = url;
      max_response_bytes = null; //optional for request
      headers = request_headers;
      body = ?request_body_as_nat8;
      method = #post;
      transform = ?transform_context;
    };

    Cycles.add(21_850_258_000);

    let http_response : Types.HttpResponsePayload = await ic.http_request(http_request);

    let response_body : Blob = Blob.fromArray(http_response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };
    let #ok(blob) = JSON.fromText(decoded_text, null);

    let transactionReceipt : ?Types.TransactionReceipt = from_candid (blob);
    transactionReceipt;
  };

  public shared (msg) func sign(deposit : Types.Params) : async {
    #Ok : { signature_hex : Text; public_key_hex : Text };
    #Err : Text;
  } {
    let caller = Principal.toBlob(msg.caller);

    let quote : ?Types.Quote = await getQuote(deposit.quoteId);

    var error : Text = "";

    switch (quote) {
      case null { error := "Quote not found" };
      case (?quote) {
        if (Text.notEqual(quote.sourceAmount, deposit.amount)) {

          error := error # "\n Source and deposit amount do not match";
        };
        if (Text.notEqual(quote.subvaultId, deposit.subvaultId)) {
          error := error # "\n Quote and deposit subvaultId do not match";
        };
        let currentTime : Int = Time.now() / 1000000000;

        let expiration : Int = quote.expiration;

        if (expiration < currentTime) {
          error := error # "\n Quote has expired. Expiration time: " # Int.toText(expiration) # " Current Time: " # Int.toText(currentTime);
        };

      };
    };

    //Fetch transaction receipt
    let transactionReceipt : ?Types.TransactionReceipt = await getTransactionReceipt(deposit.transactionHash);

    switch (transactionReceipt) {
      case null { error := error # "\n Transaction Receipt not found" };
      case (?transactionReceipt) {
        if (Text.notEqual(Text.map(transactionReceipt.result.logs[0].address, Prim.charToLower), Text.map(deposit.contractAddress, Prim.charToLower))) {
          //fail
          error := error # "\n Contract Address of deposit does not match address in transaction receipt";
        };
      };
    };

    if (Text.equal(error, "")) {
      try {
        let message_hash : Blob = Blob.fromArray(SHA256.sha256(Blob.toArray(Text.encodeUtf8(deposit.transactionHash))));
        Cycles.add(25_000_000_000);
        let { signature } = await ic.sign_with_ecdsa({
          message_hash;
          derivation_path = [caller];
          key_id = { curve = #secp256k1; name = "test_key_1" };
        });

        let { public_key } = await ic.ecdsa_public_key({
          canister_id = null;
          derivation_path = [caller];
          key_id = { curve = #secp256k1; name = "test_key_1" };
        });

        #Ok({
          signature_hex = Hex.encode(Blob.toArray(signature));
          public_key_hex = Hex.encode(Blob.toArray(public_key));
        });
      } catch (err) {
        #Err(Error.message(err));
      };
    } else {
      #Err(error);
    };

  };
};
