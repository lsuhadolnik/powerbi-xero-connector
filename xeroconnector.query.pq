// This is where you can write sample queries to test your extension.
let 
    source = XeroConnector.Contents("/connections", [
    ]),
    org = source{0}[tenantId],
    Contacts = XeroConnector.Contents("/api.xro/2.0/Contacts", [
        Headers = [
            #"Accept" = "application/json",
            #"xero-tenant-id" = org
        ]
    ]),
    Conts = List.Count(Contacts[Contacts])
     in Conts
