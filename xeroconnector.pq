section XeroConnector;

client_id = "53FDD514B6F746158EF63BB1EA077311";

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;

base_url = "https://api.xero.com";

// DONE - Refresh token -> Used the example
// TODO - Pagination -> No need.
// DONE - Load into PowerBI -> MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// DONE - TestConnection -> MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH
// DONE :( - Cannot auto refresh the source without a local gateway


//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. Credential matching is done based on the function's parameters.
// All data source functions associated to the same Data Source Kind must have a matching set of required
// function parameters, including type, name, and the order in which they appear.
[DataSource.Kind = "XeroConnector", Publish="XeroConnector.UI"]
shared XeroConnector.Contents = Value.ReplaceType(Xero.Contents, type function (optional path as text, optional org as record) as any);

//
// Data Source definition
//
XeroConnector = [
    TestConnection = (dataSourcePath) => {"XeroConnector.Contents"},
    Authentication = [
        OAuth = [
            StartLogin = StartLogin,
            FinishLogin = FinishLogin,
            Refresh = Refresh,
            Label = Extension.LoadString("AuthenticationLabel")
        ]
    ]
];

//
// UI Export definition
//
XeroConnector.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = XeroConnector.Icons,
    SourceTypeImage = XeroConnector.Icons
];

XeroConnector.Icons = [
    Icon16 = {
        Extension.Contents("xero16.png"),
        Extension.Contents("xero20.png"),
        Extension.Contents("xero24.png"),
        Extension.Contents("xero32.png")
    },
    Icon32 = {
        Extension.Contents("xero32.png"),
        Extension.Contents("xero40.png"),
        Extension.Contents("xero48.png"),
        Extension.Contents("xero64.png")
    }
];


Xero.Contents = (optional path as text, optional org as record) =>
    let
        defaultHeaders = [
            #"Accept" = "application/json"
        ],
        params = [],
        url = base_url & (if path = null then "/connections" else path),
        content = Web.Contents(url, org),
        json = Json.Document(content)
    in
        json;

//
// OAuth2 flow definition
//
StartLogin = (resourceUrl, state, display) =>
    let
        plainTextCodeVerifier = Text.NewGuid() & Text.NewGuid(),
        bEnc = (s) => Text.Replace(Text.Replace(Text.BeforeDelimiter(Binary.ToText(s,BinaryEncoding.Base64),"="),"+","-"),"/","_"),
        codeVerifier = bEnc(Crypto.CreateHash(CryptoAlgorithm.SHA256, Text.ToBinary(plainTextCodeVerifier))),
        AuthorizeUrl = "https://login.xero.com/identity/connect/authorize?"
            & Uri.BuildQueryString(
                [
                    response_type = "code",
                    client_id = "53FDD514B6F746158EF63BB1EA077311",
                    scope = "openid profile offline_access email accounting.transactions.read accounting.contacts.read",
                    state = state,
                    redirect_uri = redirect_uri,
                    code_challenge_method = "S256",
                    code_challenge = codeVerifier
                ]
            )
    in
        [
            LoginUri = AuthorizeUrl,
            CallbackUri = redirect_uri,
            WindowHeight = windowHeight,
            WindowWidth = windowWidth,
            Context = plainTextCodeVerifier
        ];

FinishLogin = (context, callbackUri, state) => let 
    Parts = Uri.Parts(callbackUri)[Query] 
in TokenMethod(Parts[code], "authorization_code", context);


TokenMethod = (code, grant_type, optional verifier) =>
    let
        codeVerifier = if (verifier <> null) then [code_verifier = verifier] else [],
        codeParameter = if (grant_type = "authorization_code") then [code = code] else [refresh_token = code],
        query = codeVerifier
            & codeParameter
            & [
                client_id = client_id,
                // Native client flows should not require a client_secret when using PKCE, but some still do.
                // client_secret = client_secret,
                grant_type = grant_type,
                redirect_uri = redirect_uri
            ],
        // Set this if your API returns a non-2xx status for login failures
        // ManualHandlingStatusCodes = {400, 403}
        ManualHandlingStatusCodes = {},
        Response = Web.Contents(
            "https://identity.xero.com/connect/token",
            [
                Content = Text.ToBinary(Uri.BuildQueryString(query)),
                Headers = [
                    #"Content-type" = "application/x-www-form-urlencoded", 
                    #"Accept" = "application/json"
                ],
                ManualStatusHandling = ManualHandlingStatusCodes
            ]
        ),
        Parts = Json.Document(Response)
    in
        // check for error in response
        if (Parts[error]? <> null) then
            error Error.Record(Parts[error], Parts[message]?)
        else
            Parts;

Refresh = (resourceUrl, refresh_token) => TokenMethod(refresh_token, "refresh_token");


