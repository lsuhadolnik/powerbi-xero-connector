section GithubSample;

client_id = "53FDD514B6F746158EF63BB1EA077311";

redirect_uri = "https://oauth.powerbi.com/views/oauthredirect.html";
windowWidth = 1200;
windowHeight = 1000;

// DONE - Refresh token -> Used the example
// TODO - Pagination
// DONE - Load into PowerBI -> MAKE SURE TO INCLUDE THE PUBLISH PROPERTY!!!
// DONE - TestConnection -> MAKE SURE TO PROVIDE THE DEFAULT VALUE FOR PATH


//
// Exported functions
//
// These functions are exported to the M Engine (making them visible to end users), and associates
// them with the specified Data Source Kind. The Data Source Kind is used when determining which
// credentials to use during evaluation. Credential matching is done based on the function's parameters.
// All data source functions associated to the same Data Source Kind must have a matching set of required
// function parameters, including type, name, and the order in which they appear.
[DataSource.Kind = "GithubSample", Publish="GithubSample.UI"]
shared GithubSample.Contents = Value.ReplaceType(Github.Contents, type function (baseUrl as Uri.Type, optional path as text, optional org as record) as any);

//
// Data Source definition
//
GithubSample = [
    TestConnection = (dataSourcePath) => {"GithubSample.Contents", dataSourcePath},
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
GithubSample.UI = [
    Beta = true,
    ButtonText = {Extension.LoadString("FormulaTitle"), Extension.LoadString("FormulaHelp")},
    SourceImage = GithubSample.Icons,
    SourceTypeImage = GithubSample.Icons
];

GithubSample.Icons = [
    Icon16 = {
        Extension.Contents("github16.png"),
        Extension.Contents("github20.png"),
        Extension.Contents("github24.png"),
        Extension.Contents("github32.png")
    },
    Icon32 = {
        Extension.Contents("github32.png"),
        Extension.Contents("github40.png"),
        Extension.Contents("github48.png"),
        Extension.Contents("github64.png")
    }
];

//
// Github.Contents - retrieves a single page of data from github and sets a
// Next link value as meta on the returned json response. We parse the json
// result (which will be a list of records) into a table.
//
Github.Contents = (baseUrl as text, optional path as text, optional org as record) =>
    let
        url = baseUrl & (if path = null then "/connections" else path),
        content = Web.Contents(url, org),
        json = Json.Document(content)
    in
        json;

Github.PagedTable = (url as text) =>
    Table.GenerateByPage(
        (previous) =>
            let
                // If we have a previous page, get its Next link from metadata on the page.
                next = if (previous <> null) then Value.Metadata(previous)[Next] else null,
                // If we have a next link, use it, otherwise use the original URL that was passed in.
                urlToUse = if (next <> null) then next else url,
                // If we have a previous page, but don't have a next link, then we're done paging.
                // Otherwise retrieve the next page.
                current = if (previous <> null and next = null) then null else Github.Contents(urlToUse),
                // If we got data back from the current page, get the link for the next page
                link = if (current <> null) then Value.Metadata(current)[Next] else null
            in
                current meta [Next = link]
    );

// This function returns an absolute URL to the next page of data.
//
// The 'response' parameter typically contains the result of the call to Web.Contents.
// The 'request' parameter is optional and contains values to formulate the request.
// It is typically used when the next link is a relative URL and needs to be
// appended to a base URL from the request. Its format is up to the extension author.
//
// The current implementation is specific to Github, which returns its next link
// in a "Link" header in the response. The 'request' parameter is not used.
// You will most likely need to replace the logic below with whatever paging
// mechanism is used by your data source.
//
GetNextLink = (response, optional request) =>
    let
        // extract the "Link" header if it exists
        link = Value.Metadata(response)[Headers][#"Link"]?,
        links = Text.Split(link, ","),
        splitLinks = List.Transform(links, each Text.Split(Text.Trim(_), ";")),
        next = List.Select(splitLinks, each Text.Trim(_{1}) = "rel=""next"""),
        first = List.First(next),
        removedBrackets = Text.Range(first{0}, 1, Text.Length(first{0}) - 2)
    in
        try removedBrackets otherwise null;

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

//
// Common code
//
// Calls the getNextPage function until it returns null.
// Each call to getNextPage expects a table of data to be returned.
// The result of the previous call to getNextPage is passed along to the next call.
// Appends all pages (tables) together into a single result.
// Returns an empty table if the first call to getNextPage returns null.
Table.GenerateByPage = (getNextPage as function) as table =>
    let
        listOfPages = List.Generate(
            () => getNextPage(null), (lastPage) => lastPage <> null, (lastPage) => getNextPage(lastPage)
        ),
        tableOfPages = Table.FromList(listOfPages, Splitter.SplitByNothing(), {"Column1"}),
        firstRow = tableOfPages{0} ?
    in
        if (firstRow = null) then
            Table.FromRows({})
        else
            Value.ReplaceType(
                Table.ExpandTableColumn(tableOfPages, "Column1", Table.ColumnNames(firstRow[Column1])),
                Value.Type(firstRow[Column1])
            );


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


