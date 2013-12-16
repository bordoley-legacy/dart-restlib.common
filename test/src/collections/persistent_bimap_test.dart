part of restlib.common.collections_test;

persistentBiMapTests() {
  new EqualsTester()
  ..addEqualityGroup(
      [Persistent.EMPTY_BIMAP,
      Persistent.EMPTY_BIMAP.insert("a", "a").removeAt("a")])
  ..addEqualityGroup(
      [Persistent.EMPTY_BIMAP.insert("a", "a").insert("b", "b"),
       Persistent.EMPTY_BIMAP.insert("b", "b").insert("a", "a"),
       Persistent.EMPTY_DICTIONARY.insertAllFromMap({"a" : "a", "b" : "b"}),
       Persistent.EMPTY_BIMAP.insert("b", "b").insert("c", "c").insert("a", "a").removeAt("c")
      ])
  ..executeTestCase();
  
  new ImmutableDictionaryTester()
    ..generator = ((final int size) => 
        Persistent.EMPTY_BIMAP.insertAll(new List.generate(size, (i) => new Pair(i,i))))
    ..invalidKey = 1001
    ..pairGenerator = new SequencePairGenerator()
    ..testSizes = [0,1,1000]
    ..testImmutableDictionary();
}