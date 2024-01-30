// This is where you can write sample queries to test your extension.
let 
    source = GithubSample.Contents("/connections", [
    ]),
    org = source{0}[tenantId],
    Contacts = GithubSample.Contents("/api.xro/2.0/Contacts", [
        Headers = [
            #"Accept" = "application/json",
            #"xero-tenant-id" = org
        ]
    ]),
    Conts = List.Count(Contacts[Contacts])
     in Conts
