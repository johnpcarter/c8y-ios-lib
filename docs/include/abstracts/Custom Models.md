c8y is highly customisable and virtually all data models can be enriched with either simply or complex types.
This obviously creates a problem for a strongly typed language such as Swift. By default any found custom structures
are flattened into string name-spaces and referenced from a property map in `JcManagedObject`, `JcAlarm` or `JcEvent` 
etc.

However the library allows you to integrate your own Classes to encode/decode these custom models. Here you will
find custom models that have already been included.