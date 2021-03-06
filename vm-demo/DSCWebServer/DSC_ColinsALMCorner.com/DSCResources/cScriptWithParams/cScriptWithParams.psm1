$GenericMessageEventID=0x1005;
$ClassName="cScriptWithParams"

# The Get-TargetResource cmdlet is used to fetch the desired state of the DSC managed node through a powershell script.
# This cmdlet executes the user supplied script (i.e., the script is responsible for validating the desired state of the 
# DSC managed node). The result of the script execution is in the form of a hashtable containing all the inormation 
# gathered from the GetScript execution.
function Get-TargetResource 
{
    [CmdletBinding()]
     param 
     (         
       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]
       $GetScript,
  
       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]$SetScript,

       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]
       $TestScript,

       [Parameter(Mandatory=$false)]
       [System.Management.Automation.PSCredential] 
       $Credential,

       [Parameter(Mandatory=$false)]
       [Microsoft.Management.Infrastructure.CimInstance[]]
       $cParams
     )

    $getTargetResourceResult = $null;

    Write-Debug -Message "Begin executing Get Script."
 
    $script = [ScriptBlock]::Create($GetScript);
    $parameters = $psboundparameters.Remove("GetScript");
    $psboundparameters.Add("ScriptBlock", $script);
    $psboundparameters.Add("customParams", $cParams);

    $parameters = $psboundparameters.Remove("SetScript");
    $parameters = $psboundparameters.Remove("TestScript");

    $scriptResult = ScriptExecutionHelper @psboundparameters;
  
    $scriptResultAsErrorRescord = $scriptResult -as [System.Management.Automation.ErrorRecord]
    if($null -ne $scriptResultAsErrorRescord)
    {
        $PSCmdlet.ThrowTerminatingError($scriptResultAsErrorRescord);
    }

    $scriptResultAsHasTable = $scriptResult -as [hashtable]

    if($null -ne $scriptResultAsHasTable)
    {
        $getTargetResourceResult = $scriptResultAsHasTable ;
    }
    else
    {
        # Error message indicating failure to get valid hashtable as the result of the Get script execution.
        $errorId = "InValidResultFromGetScript"; 
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult;
        $exception = New-Object System.InvalidOperationException "Failure to get the results from the script in a hash table format."; 
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }

    Write-Debug -Message "End executing Get Script."

    $getTargetResourceResult;
}


# The Set-TargetResource cmdlet is used to Set the desired state of the DSC managed node through a powershell script.
# The method executes the user supplied script (i.e., the script is responsible for validating the desired state of the 
# DSC managed node). If the DSC managed node requires a restart either during or after the execution of the SetScript,
# the SetScript notifies the PS Infrasturcure by setting the variable $DSCMachineStatus.IsRestartRequired to $true.
function Set-TargetResource 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
     param 
     (       
       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]
       $SetScript,

       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]
       $GetScript,

       [Parameter(Mandatory=$false)]
       [System.Management.Automation.PSCredential] 
       $Credential,

       [parameter(Mandatory = $true)]
       [ValidateNotNullOrEmpty()]
       [string]
       $TestScript,

       [Parameter(Mandatory=$false)]
       [Microsoft.Management.Infrastructure.CimInstance[]]
       $cParams
 )

    $setscriptmessage = '$SetScript:' + $SetScript
    $testscriptmessage = '$TestScript:' + $TestScript
    if ($pscmdlet.ShouldProcess("Executing the SetScript with the user supplied credential")) 
    {
        Write-Debug -Message "Begin executing Set Script."

        $script = [ScriptBlock]::Create($SetScript);
        $parameters = $psboundparameters.Remove("SetScript");
        $psboundparameters.Add("ScriptBlock", $script);
        $psboundparameters.Add("customParams", $cParams);

        $parameters = $psboundparameters.Remove("GetScript");
        $parameters = $psboundparameters.Remove("TestScript");

        $scriptResult = ScriptExecutionHelper @psboundparameters ;

        $scriptResultAsErrorRescord = $scriptResult -as [System.Management.Automation.ErrorRecord]
        if($null -ne $scriptResultAsErrorRescord)
        {
            $PSCmdlet.ThrowTerminatingError($scriptResultAsErrorRescord);
        }
        
        Write-Debug -Message "End executing Set Script."
    }
}


# The Test-TargetResource cmdlet is used to validate the desired state of the DSC managed node through a powershell script.
# The method executes the user supplied script (i.e., the script is responsible for validating the desired state of the 
# DSC managed node). The result of the script execution should be true if the DSC managed machine is in the desired state
# or else false should be returned.
function Test-TargetResource 
{
    param 
    (       
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $TestScript,
  
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SetScript,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$GetScript,

        [Parameter(Mandatory=$false)]
        [System.Management.Automation.PSCredential] 
        $Credential,

        [Parameter(Mandatory=$false)]
        [Microsoft.Management.Infrastructure.CimInstance[]]
        $cParams
    )

    $testTargetResourceResult = $false;

    Write-Debug -Message "Begin executing Test Script."
    
    $script = [ScriptBlock]::Create($TestScript);
    $parameters = $psboundparameters.Remove("TestScript");
    $psboundparameters.Add("ScriptBlock", $script);
    $psboundparameters.Add("customParams", $cParams);

    $parameters = $psboundparameters.Remove("GetScript");
    $parameters = $psboundparameters.Remove("SetScript");
    
    $scriptResult = ScriptExecutionHelper @psboundparameters ;

    $scriptResultAsErrorRescord = $scriptResult -as [System.Management.Automation.ErrorRecord]
    if($null -ne $scriptResultAsErrorRescord)
    {
        $PSCmdlet.ThrowTerminatingError($scriptResultAsErrorRescord);
    }

    if($null -eq $scriptResult)
    {
        $errorId = "InValidResultFromTestScript"; 
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult;
        $exception = New-Object System.InvalidOperationException "TestScript returned null. The Test script should return True or False.";
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }

    # If the script is returing multiple objects, then we consider the last object to be the result of script execution.
    if($scriptResult.GetType().ToString() -eq 'System.Object[]')
    {
        $reultObject = $scriptResult[$scriptResult.Length -1];
    }
    else
    {
        $reultObject = $scriptResult;
    }

    if(($null -ne $reultObject) -and 
       (($reultObject -eq $true) -or ($reultObject -eq $false)))
    {
        $testTargetResourceResult = $reultObject;
    }
    else
    {
        $errorId = "InValidResultFromTestScript"; 
        $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidResult;
        $exception = New-Object System.InvalidOperationException "Failure to get a valid result from the execution of TestScript. The Test script should return True or False.";
        $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $null

        $PSCmdlet.ThrowTerminatingError($errorRecord);
    }

    Write-Debug -Message "Result of test script is: $testTargetResourceResult"

    Write-Debug -Message "End executing Test Script."

    $testTargetResourceResult;
}


function ScriptExecutionHelper 
{
    param 
    (
        [ScriptBlock] 
        $ScriptBlock,
    
        [System.Management.Automation.PSCredential] 
        $Credential,

        [Microsoft.Management.Infrastructure.CimInstance[]]
        $customParams
    )

    $scriptExecutionResult = $null;

    try
    {
        $executingScriptMessage = "Executing script: {0}" -f ${ScriptBlock} ;
        Write-Debug -Message $executingScriptMessage;

        $executingScriptArgsMessage = "Script params: {0}" -f $customParams ;
        Write-Debug -Message $executingScriptArgsMessage;

        # bring the cParams into memory
        foreach($cVar in $customParams.GetEnumerator())
        {
            Write-Debug -Message "Creating value $($cVar.Key) with value $($cVar.Value)"
            New-Variable -Name $cVar.Key -Value $cVar.Value
        }

        if($null -ne $Credential)
        {
           $scriptExecutionResult = Invoke-Command -ScriptBlock $ScriptBlock -ComputerName . -Credential $Credential
        }
        else
        {
           $scriptExecutionResult = &$ScriptBlock;
        }
        Write-Debug -Message "Completed script execution"
        $scriptExecutionResult;
    }
    catch
    {
        # Surfacing the error thrown by the execution of Get/Set/Test script.
        $_;
    }
}

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource