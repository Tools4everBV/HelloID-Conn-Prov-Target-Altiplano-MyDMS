#################################################################
# HelloID-Conn-Prov-Target-Altiplano-MyDMS-RevokePermission-Group
# PowerShell V2
#################################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions
function Resolve-MyDMSError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = $ErrorObject.Exception.Message
            FriendlyMessage  = $ErrorObject.Exception.Message
        }
        if (-not [string]::IsNullOrEmpty($ErrorObject.ErrorDetails.Message)) {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            if ($null -ne $ErrorObject.Exception.Response) {
                $streamReaderResponse = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
                if (-not [string]::IsNullOrEmpty($streamReaderResponse)) {
                    $httpErrorObj.ErrorDetails = $streamReaderResponse
                }
            }
        }
        try {
            $errorDetailsObject = ($httpErrorObj.ErrorDetails | ConvertFrom-Json)
            # Not implemented, but here you can parse the error details from MyDMS to a more user-friendly message
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails # Temporarily assignment
        }
        catch {
            $httpErrorObj.FriendlyMessage = $httpErrorObj.ErrorDetails
            Write-Warning $_.Exception.Message
        }
        Write-Output $httpErrorObj
    }
}
#endregion

# Begin
try {
    # Verify if [accountReference] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    $pair = "$($actionContext.Configuration.UserName):$($actionContext.Configuration.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $headers = @{
        Authorization = "Basic $encodedCreds"
    }

    try {
        Write-Information 'Verifying if a MyDMS account exists'
        $splatGetUserParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/user?id=$($actionContext.References.Account))"
            Method  = 'GET'
            Headers = $headers
        }
        $correlatedAccount = Invoke-RestMethod @splatGetUserParams
    }
    catch {
        $errorObj = Resolve-MyDMSError -ErrorObject $PSItem
        if ($errorObj.FriendlyMessage -notmatch 'User account not found') {
            throw $_
        }
    }

    if ($null -ne $correlatedAccount) {
        $lifecycleProcess = 'RevokePermission'
    }
    else {
        $lifecycleProcess = 'NotFound'
    }

    # Process
    switch ($lifecycleProcess) {
        'RevokePermission' {

            # Make sure to test with special characters and if needed; add utf8 encoding.
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information "Revoking MyDMS permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)]"
                $splatRevokeParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/user?id=$($actionContext.References.Account)&groupId=$($actionContext.References.Permission.Reference)"
                    Method      = 'DELETE'
                    Headers     = $headers
                    ContentType = 'application/json'
                }
                $null = Invoke-RestMethod @splatRevokeParams
            }
            else {
                Write-Information "[DryRun] Revoke MyDMS permission: [$($actionContext.PermissionDisplayName)] - [$($actionContext.References.Permission.Reference)], will be executed during enforcement"
            }

            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Revoke permission: [$($actionContext.PermissionDisplayName)] from [$($actionContext.References.Account)] was successful. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }

        'NotFound' {
            Write-Information "MyDMS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted"
            $outputContext.Success = $true
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "MyDMS account: [$($actionContext.References.Account)] could not be found, indicating that it may have been deleted. Action initiated by: [$($actionContext.Origin)]"
                    IsError = $false
                })
            break
        }
    }
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MyDMSError -ErrorObject $ex
        $auditLogMessage = "Could not revoke MyDMS permission for account: [$($actionContext.References.Account)]. Error: $($errorObj.FriendlyMessage). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not revoke MyDMS permission for account: [$($actionContext.References.Account)]. Error: $($_.Exception.Message). Action initiated by: [$($actionContext.Origin)]"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}