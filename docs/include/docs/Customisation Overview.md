# Customisation Overview #

c8y is highly customisable and virtually all data models can be enriched with either simply or complex types.
This obviously creates a problem for a strongly typed language such as Swift. By default any found custom structures
are flattened into string name-spaces and referenced from a property map in `JcManagedObject`, `JcAlarm` or `JcEvent` 
etc.

This section explains how you override this default behaviour to provide you own classes that replace the 
default behaviour.