section XeroConnector;

client_id = "53FDD514B6F746158EF63BB1EA077311";
required_scopes = "openid profile offline_access email accounting.transactions.read accounting.contacts.read";


windowWidth = 600;
windowHeight = 800;


redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
base_url = "https://api.xero.com";


// TODO - Pagination -> No need.
// DONE - Refresh token -> Used the example
// DONE - Load into PowerBI -> MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// DONE - TestConnection -> MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH
// DONE :( - Cannot auto refresh the source without a gateway


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
                    client_id = client_id,
                    scope = required_scopes,
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
                grant_type = grant_type,
                redirect_uri = redirect_uri
            ],

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

//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. 
//
// IMPORTANT - Credential matching is done based on the function's REQUIRED parameters.
// You can have as many different optional params, but the REQUIRED params must MATCH in every shared method.
//
// All data source functions associated to the same Data Source Kind must have a matching set of REQUIRED
// function parameters, including type, name, and the order in which they appear.
[DataSource.Kind = "XeroConnector", Publish="XeroConnector.UI"]
shared XeroConnector.Contents = Value.ReplaceType(Xero.Contents, type function (optional endpoint as text, optional tenantId as text, optional additionalParams as record) as any);

Xero.Contents = (optional endpoint as text, optional tenantId as text, optional additionalParams as record) =>
    let
        connectionsPath = base_url & "/connections",
        defaultHeaders = [
            #"Accept" = "application/json"
        ],
        params = [],
        url = (if endpoint = null then connectionsPath else endpoint),
        content = Web.Contents(url, [
            Headers = defaultHeaders & 
            (if tenantId = null then [] else [#"xero-tenant-id" = tenantId])
        ]),
        json = Json.Document(content)
    in
        json;

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


