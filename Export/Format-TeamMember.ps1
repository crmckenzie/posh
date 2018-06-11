function Format-TeamMember(){
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Name,

        [Alias("Value")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Title
    )
    Begin {
        # Do one-time operations needed to support the pipe here
    }
    Process {
        return "Name: $Name; Title: $Title" # Use the newly renamed parameter
    }
    End {
        # Cleanup before the pipe closes here
    }

}