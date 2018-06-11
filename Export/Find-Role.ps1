function Find-Role(){
    param(
        [Parameter(Mandatory, ValueFromPipeline)] $item,
        [switch] $ServiceEngineer
    )

    Begin {
    }
    Process {
        if ($ServiceEngineer) {
            if ($item.Value -eq "Service Engineer") {
                return $item
            }
        }

        if (-not $ServiceEngineer) {
            # if no filter is requested then return everything.
            return $item
        }

        return; # not technically required but shows the exit when nothing an item is filtered out.
    }
    End {
    }
}