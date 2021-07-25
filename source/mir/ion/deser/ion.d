/++
+/
module mir.ion.deser.ion;

import mir.ion.value: IonDescribedValue;

/++
+/
template deserializeIon(T)
{
    /++
    +/
    T deserializeIon(scope const(ubyte)[] data)
    {
        import mir.serde: SerdeException;
        import mir.ion.stream: IonValueStream;

        foreach (symbolTable, ionValue; IonValueStream(data))
        {
            return deserializeIon!T(symbolTable, ionValue);
        }

        static immutable exc = new SerdeException("Ion data doesn't contain a value");
        throw exc;
    }

    /++
    +/
    T deserializeIon(scope const char[][] symbolTable, IonDescribedValue ionValue)
    {
        import mir.appender: ScopedBuffer;
        import mir.ion.deser: deserializeValue;
        import mir.serde: serdeGetDeserializationKeysRecurse, SerdeException;
        import mir.string_table: createTable;

        static if (__traits(hasMember, T, "deserializeFromIon"))
            enum keys = string[].init;
        else
            enum keys = serdeGetDeserializationKeysRecurse!T;

        alias createTableChar = createTable!char;
        static immutable table = createTableChar!(keys, false);

        T value;
        if (false)
        {
            auto msg = deserializeValue!(keys, true)(ionValue, symbolTable, null, value);
        }
        () @trusted {

            ScopedBuffer!(uint, 1024) tableMapBuffer = void;
            tableMapBuffer.initialize;

            foreach (key; symbolTable)
            {
                uint id;
                if (!table.get(key, id))
                    id = uint.max;
                tableMapBuffer.put(id);
            }

            if (auto exception = deserializeValue!(keys, true)(ionValue, symbolTable, tableMapBuffer.data, value))
                throw exception;
            
        } ();
        return value;
    }

    /// ditto
    // the same code with GC allocated symbol table
    T deserializeIon(immutable char[][] symbolTable, IonDescribedValue ionValue)
    {
        import mir.appender: ScopedBuffer;
        import mir.ion.deser: deserializeValue;
        import mir.serde: serdeGetDeserializationKeysRecurse, SerdeException;
        import mir.string_table: MirStringTable;

        static if (__traits(hasMember, T, "deserializeFromIon"))
            static immutable keys = string[].init;
        else
            static immutable keys = serdeGetDeserializationKeysRecurse!T;

        alias Table = MirStringTable!(keys.length, keys.length ? keys[$ - 1].length : 0);

        static if (keys.length)
            static immutable table = Table(keys[0 .. keys.length]);
        else
            static immutable table = Table.init;

        T value;
        if (false)
        {
            auto msg = deserializeValue!(keys, true)(ionValue, symbolTable, null, value);
        }
        () @trusted {

            ScopedBuffer!(uint, 1024) tableMapBuffer = void;
            tableMapBuffer.initialize;

            foreach (key; symbolTable)
            {
                uint id;
                if (!table.get(key, id))
                    id = uint.max;
                tableMapBuffer.put(id);
            }

            if (auto exception = deserializeValue!(keys, true)(ionValue, symbolTable, tableMapBuffer.data, value))
                throw exception;
            
        } ();
        return value;
    }
}

///
unittest
{
    alias d = deserializeIon!(int[string]);
}