#################################################
# HelloID-Conn-Prov-Target-Altiplano-MyDMS-Create
# PowerShell V2
#################################################

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

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # Prepare headers
    $pair = "$($actionContext.Configuration.UserName):$($actionContext.Configuration.Password)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $headers = @{
        Authorization = "Basic $encodedCreds"
    }

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.AccountField -replace '_', ''
        $correlationValue = $actionContext.CorrelationConfiguration.PersonFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        try {
            Write-Information "Verifying if a MyDMS account exists where $correlationField is: [$correlationValue]"
            $splatGetUserParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/user?$($correlationField)=$([uri]::EscapeDataString("$correlationValue"))"
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
    }

    if ($null -eq $correlatedAccount) {
        $lifecycleProcess = 'CreateAccount'
    }
    else {
        $lifecycleProcess = 'CorrelateAccount'
    }

    # Process
    switch ($lifecycleProcess) {
        'CreateAccount' {
            $actionContext.Data | Add-Member @{
                _startEmployment = (Get-Date).AddDays(-1).ToString('dd-MM-yyyy')
                _endEmployment   = (Get-Date).AddDays(-1).ToString('dd-MM-yyyy')
            }
            $splatCreateParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/user"
                Method      = 'POST'
                Headers     = $headers
                ContentType = 'application/json'
                Body        = $actionContext.Data | ConvertTo-Json -Depth 10
            }
            if (-not($actionContext.DryRun -eq $true)) {
                Write-Information 'Creating and correlating MyDMS account'

                $createdAccount = Invoke-RestMethod @splatCreateParams
                $outputContext.Data = $createdAccount | Select-Object -Property $actionContext.Data.PSObject.Properties.Name
                $outputContext.AccountReference = $createdAccount._id
            }
            else {
                Write-Information '[DryRun] Create and correlate MyDMS account, will be executed during enforcement'
            }
            $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)]"
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating MyDMS account'
            $outputContext.Data = $correlatedAccount | Select-Object -Property $actionContext.Data.PSObject.Properties.Name
            $outputContext.AccountReference = $correlatedAccount._id
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($outputContext.AccountReference)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $lifecycleProcess
            Message = $auditLogMessage
            IsError = $false
        })
}
catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-MyDMSError -ErrorObject $ex
        $auditLogMessage = "Could not create or correlate MyDMS account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditLogMessage = "Could not create or correlate MyDMS account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditLogMessage
            IsError = $true
        })
}