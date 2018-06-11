# My Favorite Powershell Features You're Not Using

## Contents

* [Destructuring](##Destructuring)
* [Array Comparisons](##Array-Comparisons)
    * [Null Coalesce](###Null-Coalesce)
* [Module Structure](##Module-Structure)
* [Piping](##Piping)
    * [The Naive Solution](###The-Naive-Solution)
    * [Convert To Singular](###Convert-to-Singular)
    * [Begin, Process, End](###Begin,-Process,-End)
    * [ValueFromPipeLine... ByPropertyName](###ValueFromPipeLine...-ByPropertyName)
    * [Alias](###Alias)
    * [Pipe Forwarding](###Pipe-Forwarding)
    * [Filtering](###Filtering)

## Destructuring

What is *destructuring?*

    Destructuring is a convenient way of extracting multiple values from data stored in (possibly nested) objects and Arrays. It can be used in locations that receive data (such as the left-hand side of an assignment).

[source](exploringjs.com/es6/ch_destructuring.html)

Here is an example of destructuring in powershell.

```powershell
$first, $second, $therest = 1,2,3,4,5
$first
1
$second
2
$therest
3
4
5
```

As you can see, Powershell assigns the first and second values in the array to the variables `$first` and `$second`. The remaining items are then assigned to the last variable in the assignment list.

## Array Comparisons

There is a shorthand syntax that can be applied to arrays to apply filtering. Consider the following syntactically correct Powershell:

```powershell
1,2,3,4,5 | ?{ $_ -gt 2 } # => 3,4,5
```

You can write the same thing in a much simpler fashion as follows:

```powershell
1,2,3,4,5 -gt 2 => 3,4,5
```

In the second example, Powershell is applying the expression `-gt 2` to the elements of array and returning the matching items. 

### Null Coalesce

Unfortnately, Powershell lacks a true null coalesce operator. Fortunately, we can simulate that behavior using array comparisons.

```powershell
($null, $null, 5,6, $null, 7).Length # => 6
($null, $null, 5,6, $null, 7 -ne $null).Length # => 3
($null, $null, 5,6, $null, 7 -ne $null)[0] # => 5

```

## Module Structure

There doesn't seem to be much guidance as to the internal structure of a module. This is what I've come up with.

* `/Module.psd1`
This is a powershell module manifest. It contains the metadata about the powershell module, including the name, version, unique id, dependencies, etc..

* `/Module.psm1`
This is the module file that contains or loads your functions. I personally prefer to separate each function into its own file. 

* `/Export/Export-Function.ps1`
I keep functions I want the module to export in this directory. This makes them easy to identify and to export from the `.psm1` file.

* `/Private/Private-Function.ps1`
I keep helper functions I do not wish to expose to module clients here. This makes it easy to exclude them from the calls to `Export-ModuleMember` in the `.psm1` file.

* `/Tests/Export-Function.Tests.ps1`
The `Tests` directory contains all of my [Pester](https://github.com/pester/Pester) tests.

## Piping

Piping is probably one of the most underutilized feature of Powershell that I've seen in the wild. Here's a simple rule of thumb: if you find yourself writing a foreach loop in Powershell with more than just a line or two in the body, you might be doing something wrong.

Consider the following output from a function called `Get-Team`:

```powershell
----    -----
Chris   Manager
Paul    Service Engineer
Anthony Service Engineer
Nelson  Service Engineer
Kiran   Service Engineer
Raj     Software Engineer
Matt    Software Engineer
Michael Software Engineer
Shad    Software Engineer
Olga    Software Engineer
```

Let's say I want to output the name and title. I might write the Powershell as follows:

```powershell
$data = Get-Team
foreach($item in $data) {
    write-host "Name: $($item.Name); Title: $($item.Value)"
}
```

I could also use the Powershell `ForEach-Object` function to do this instead of the `foreach` block.

```powershell
# % is a short-cut to ForEach-Object
Get-Team | %{
    write-host "Name: $($_.Name); Title: $($_.Value)"
}
```
This is pretty clean given that the `foreach` block is only one line. I'm going to ask you to use your imagination and pretend that our logic is more complex than that. In a situation like that I would prefer to write something that looks more like the following:

```powershell
Get-Team | Format-TeamMember
```

But how do you write a function like `Format-TeamMember` that can participate in the Piping behavior of Powershell? There is documenation about this, but it is often far from the introductory documentation and thus I have rarely seen it used by engineers in their day to day scripting in the real world.

### The Naive Solution

Let's start with the naive solution and evolve the function toward something more elegant.

```powershell
Function Format-TeamMember() {
    param([Parameter(Mandatory)] [array] $data)
    $data | %{
        write-host "Name: $($_.Name); Title: $($_.Value)"
    }
}

# Usage
$data = Get-Team
Format-TeamMember -Data $Data
```

At this point the function is just a wrapper around the `foreach` loop from above and thus adds very little value beyond isolating the foreach logic.

Let me draw your attention to the `$data` parameter. It's defined as an `array` which is good since we're going to pipe the array to a `foreach` block. The first step toward supporting pipes in Powershell functions is to convert list parameters into their singular form.

### Convert to Singular

```powershell
Function Format-TeamMember() {
    param([Parameter(Mandatory)] $item)
    write-host "Name: $($item.Name); Title: $($item.Value)"
}

# Usage
Get-Team | %{
    Format-TeamMember -Item $_
}
```

Now that we've converted `Format-TeamMember` to work with single elements, we are ready to add support for piping.

### Begin, Process, End

The powershell pipe functionality requires a little extra overhead to support. There are three blocks that must be defined in your function, and all of your executable code should be defined in one of those blocks.

* `Begin` fires when the first element in the pipe is processed (when the pipe _opens_.) Use this block to initialize the function with data that can be cached over the lifetime of the pipe.
* `Process` fires once per element in the pipe.
* `End` fires when the last element in the pipe is processed (or when the pipe _closes_.) Use this block to cleanup after the pipe executes.

Let's add these blocks to `Format-TeamMember`.

```powershell
Function Format-TeamMember() {
    param([Parameter(Mandatory)] $item)

    Begin {
        write-host "Format-TeamMember: Begin" -ForegroundColor Green
    }
    Process {
        write-host "Name: $($item.Name); Title: $($item.Value)"
    }
    End {
        write-host "Format-TeamMember: End" -ForegroundColor Green
    }
}

# Usage
Get-Team | Format-TeamMember 

#Output
cmdlet Format-TeamMember at command pipeline position 2
Supply values for the following parameters:
item:
```

Oh noes! Now Powershell is asking for manual input! No worries--There's one more thing we need to do to support pipes.

### ValueFromPipeLine... ByPropertyName

If you want data to be piped from one function into the next, you have to tell the receiving function which parameters will be received from the pipeline. You do this by means of two attributes: `ValueFromPipeline` and `ValueFromPipelineByPropertyName`.

#### ValueFromPipeline

The `ValueFromPipeline` attribute tells the Powershell function that it will receive the _whole value_ from the previous function in thie pipe.

```powershell
Function Format-TeamMember() {
    param([Parameter(Mandatory, ValueFromPipeline)] $item)

    Begin {
        write-host "Format-TeamMember: Begin" -ForegroundColor Green
    }
    Process {
        write-host "Name: $($item.Name); Title: $($item.Value)"
    }
    End {
        write-host "Format-TeamMember: End" -ForegroundColor Green
    }
}

# Usage
Get-Team | Format-TeamMember

#Output
Format-TeamMember: Begin
Name: Chris; Title: Manager
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer
Name: Raj; Title: Software Engineer
Name: Matt; Title: Software Engineer
Name: Michael; Title: Software Engineer
Name: Shad; Title: Software Engineer
Name: Olga; Title: Software Engineer
Format-TeamMember: End
```

#### ValueFromPipelineByPropertyName

This is great! We've really moved things forward! But we can do better.

Our `Format-TeamMember` function now requires knowledge of the schema of the data from the calling function. The function is not self-contained in a way to make it maintainable or usable in other contexts. Instead of piping the whole object into the function, let's pipe the discrete values the function depends on instead.

```powershell
Function Format-TeamMember() {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Name,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Value
    )

    Begin {
        write-host "Format-TeamMember: Begin" -ForegroundColor Green
    }
    Process {
        write-host "Name: $Name; Title: $Value"
    }
    End {
        write-host "Format-TeamMember: End" -ForegroundColor Green
    }
}

# Usage
Get-Team | Format-TeamMember

# Output
Format-TeamMember: Begin
Name: Chris; Title: Manager
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer
Name: Raj; Title: Software Engineer
Name: Matt; Title: Software Engineer
Name: Michael; Title: Software Engineer
Name: Shad; Title: Software Engineer
Name: Olga; Title: Software Engineer
Format-TeamMember: End
```

### Alias

In our last refactoring, we set out to make `Format-TeamMember` self-contained. Our introduction of the `Name` and `Value` parameters decouple us from having to know the schema of the previous object in the pipeline--_almost_. We had to name our parameter `Value` which is not really how `Format-TeamMember` thinks of that value. It thinks of it as the `Title`--but in the context of our contrived module, `Value` is sometimes another name that is used. In Powershell, you can use the `Alias` attribute to support multiple names for the same parameter.

```powershell
Function Format-TeamMember() {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Name,
        [Alias("Value")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Title # Change the name to Title
    )

    Begin {
        write-host "Format-TeamMember: Begin" -ForegroundColor Green
    }
    Process {
        write-host "Name: $Name; Title: $Title" # Use the newly renamed parameter
    }
    End {
        write-host "Format-TeamMember: End" -ForegroundColor Green
    }
}

# Usage
Get-Team | Format-TeamMember

# Output
Format-TeamMember: Begin
Name: Chris; Title: Manager
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer
Name: Raj; Title: Software Engineer
Name: Matt; Title: Software Engineer
Name: Michael; Title: Software Engineer
Name: Shad; Title: Software Engineer
Name: Olga; Title: Software Engineer
Format-TeamMember: End
```

### Pipe Forwarding

Our `Format-TeamMember` function now supports _receiving_ data from the pipe, but it does not return any information that can be forwarded to the next function in the pipeline. We can change that by `returning` the formatted line instead of calling `Write-Host`. 

```powershell
Function Format-TeamMember() {
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Name,
        [Alias("Value")]
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Title # Change the name to Title
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

# Usage
[array] $output = Get-Team | Format-TeamMember
write-host "The output contains $($output.Length) items:"
$output | Out-Host

# Output
The output contains 10 items:
Name: Chris; Title: Manager
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer
Name: Raj; Title: Software Engineer
Name: Matt; Title: Software Engineer
Name: Michael; Title: Software Engineer
Name: Shad; Title: Software Engineer
Name: Olga; Title: Software Engineer

```

### Filtering

This is a lot of information. What if we wanted to filter the data so that we only see the people with the title "Service Engineer?" Let's implement a function that filters data out of the pipe.

```powershell
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
```

This should be self-explanatory for the most part. Let me draw your attention though to the `return;` statement that isn't technically required. A mistake I've seen made in this scenario is to return `$null`. If you return `$null` it adds `$null` to the pipeline as it if were a return value. If you want to exclude an item from being forwarded through the pipe you must not return anything. While the `return;` statement is not syntactically required by the language, I find it helpful to communicate my intention that I am deliberately not adding an element to the pipe.

Now let's look at usage:

```powershell
Get-Team | Find-Role | Format-Data # No Filter
Name: Chris; Title: Manager
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer
Name: Raj; Title: Software Engineer
Name: Matt; Title: Software Engineer
Name: Michael; Title: Software Engineer
Name: Shad; Title: Software Engineer
Name: Olga; Title: Software Engineer

Get-Team | Find-Role -ServiceEngineer | Format-TeamMember # Filtered
Name: Paul; Title: Service Engineer
Name: Anthony; Title: Service Engineer
Name: Nelson; Title: Service Engineer
Name: Kiran; Title: Service Engineer

```