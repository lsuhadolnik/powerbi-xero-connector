// This is where you can write sample queries to test your extension.
let 
    source = GithubSample.Contents("https://api.xero.com", "/connections", [
    ]),
    org = source{0}[tenantId],
    Contacts = GithubSample.Contents("https://api.xero.com", "/api.xro/2.0/Invoices", [
        Headers = [
            #"Accept" = "application/json",
            #"xero-tenant-id" = org
        ]
    ]),
    Conts = Table.FromRecords(Contacts[Invoices]),
    Count = Table.RowCount(Conts)
     in Count
