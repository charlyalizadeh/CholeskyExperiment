## Source: https://stackoverflow.com/questions/2997004/using-map-reduce-for-mapping-the-properties-in-a-collection
## ## It's a little mess.
## ## This way of finding the key names is not nice but it works.
## ## TODO: Find a better way to do this
"""
    computefeatureskeys(collection::Mongoc.Collection)

Compute the features keys of a collection with a max depth of 2 (I couldn't get the expected results for a depth > 3).
The keys are stored in another collection named `\$(collection.name)_keys`.
"""
function computefeatureskeys(collection::Mongoc.Collection)
        mapper = Mongoc.BSONCode(""" 
            function(){
              for(var key in this["features"]) {
                if(typeof this["features"][key] == 'object'){
                    for(var subkey in this["features"][key]) {
                        emit(key + "." + subkey, null);
                    }
                }
                else {
                    emit(key, null);
                }
              }
            }
        """)
    reducer = Mongoc.BSONCode("""function(key, stuff) { return null; }""")
    map_reduce_command = Mongoc.BSON()
    map_reduce_command["mapReduce"] = collection.name
    map_reduce_command["map"] = mapper
    map_reduce_command["reduce"] = reducer
    map_reduce_command["out"] = "$(collection.name)_keys"
    result = Mongoc.read_command(collection.database, map_reduce_command)
    return result
end
