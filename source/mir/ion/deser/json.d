/++
+/
module mir.ion.deser.json;

public import mir.serde;

version(D_Exceptions)
{
    import mir.serde: SerdeException;
}

/++
+/
T deserializeJson(T)(scope const(char)[] text)
{
    T value;    
    if (auto exc = deserializeValueFromJson(text, value))
        throw exc;
    return value;
}

/// Test @nogc deserialization
@safe pure @nogc
unittest
{
    import mir.serde: serdeIgnoreIn, serdeIgnore, serdeScoped;
    import mir.bignum.decimal;
    import mir.rc.array;
    import mir.small_array;
    import mir.small_string;

    static struct Book
    {
        SmallString!64 title;
        bool wouldRecommend;
        SmallString!128 description; // common `string` and array can be used as well (with GC)
        uint numberOfNovellas;
        Decimal!1 price;
        double weight;

        // nogc small-array tags
        SmallArray!(SmallString!16, 10) smallArrayTags;

        // nogc rc-array tags
        RCArray!(SmallString!16) rcArrayTags;

        // nogc scope array tags
        // when used with `@property` and `@serdeScoped`
        @serdeIgnore bool tagsSet; // control flag for test

        @serdeScoped
        void tags(scope SmallString!16[] tags) @property @safe pure nothrow @nogc
        {
            assert(tags.length == 3);
            assert(tags[0] == "one");
            assert(tags[1] == "two");
            assert(tags[2] == "three");
            tagsSet = true;
        }
    }

    auto book = q{{
        "title": "A Hero of Our Time",
        "wouldRecommend": true,
        "description": null,
        "numberOfNovellas": 5,
        "price": 7.99,
        "weight": 6.88,
        "tags": [
            "one",
            "two",
            "three"
        ],
        "rcArrayTags": [
            "russian",
            "novel",
            "19th century"
        ],
        "smallArrayTags": [
            "4",
            "5",
            "6"
        ]
        }}
        .deserializeJson!Book;

    import mir.conv: to;

    assert(book.description.length == 0);
    assert(book.numberOfNovellas == 5);
    assert(book.price.to!double == 7.99);
    assert(book.tagsSet);
    assert(book.rcArrayTags.length == 3);
    assert(book.rcArrayTags[0] == "russian");
    assert(book.rcArrayTags[1] == "novel");
    assert(book.rcArrayTags[2] == "19th century");
    assert(book.smallArrayTags.length == 3);
    assert(book.smallArrayTags[0] == "4");
    assert(book.smallArrayTags[1] == "5");
    assert(book.smallArrayTags[2] == "6");
    assert(book.title == "A Hero of Our Time");
    assert(book.weight == 6.88);
    assert(book.wouldRecommend);
}

/++
+/
SerdeException deserializeValueFromJson(T)(scope const(char)[] text, ref T value)
{
    import mir.ion.deser: deserializeValue;
    import mir.ion.exception: ionException;
    import mir.ion.internal.data_holder;
    import mir.ion.internal.stage4_s;
    import mir.ion.value: IonDescribedValue, IonValue;
    import mir.serde: serdeGetDeserializatinKeysRecurse;
    import mir.string_table: MirStringTable, minimalIndexType;

    enum nMax = 8192u;
    enum keys = serdeGetDeserializatinKeysRecurse!T;
    static immutable table = MirStringTable!(minimalIndexType!(keys.length))(keys);
    auto tapeHolder = IonDataHolder!(nMax * 8)(nMax * 8);
    size_t tapeLength;

    if (auto error = singleThreadJsonImpl!nMax(text, table, tapeHolder, tapeLength))
        return error.ionException;

    IonDescribedValue ionValue;

    if (auto error = IonValue(tapeHolder.data[0 .. tapeLength]).describe(ionValue))
        return error.ionException;

    return deserializeValue!(keys)(ionValue, value);
}