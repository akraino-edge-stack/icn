var bulk = db.images.initializeUnorderedBulkOp();
bulk.insert({image_name : "123abc", owner : "Enyinna", description : {
  image_records: [
    {
      image_record_name: "77af",
      repo: "docker",
      tag:  "latest",},
    ]
  }
});
bulk.insert({image_name : "456abc", owner : "Enyinna", description : {
  image_records: [
    {
      image_record_name: "746b",
      repo: "postgres",
      tag:  "9.3",},
    ]
  }
});
bulk.execute();
