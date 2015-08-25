require 'test_helper'
require 'salvage_collection'

# Valid manifest_text
TEST_MANIFEST = ". 341dabea2bd78ad0d6fc3f5b926b450e+85626+Ad391622a17f61e4a254eda85d1ca751c4f368da9@55e076ce 0:85626:brca2-hg19.fa\n. d7321a918923627c972d8f8080c07d29+82570+A22e0a1d9b9bc85c848379d98bedc64238b0b1532@55e076ce 0:82570:brca1-hg19.fa\n"

# This invalid manifest_text has the following flaws:
#   Missing stream name with locator in it's place
#   Two invalid locators:
#     341dabea2bd78ad0d6fc3f5b926b450e+abc
#     341dabea2bd78ad0d6fc3f5b926b450e
# Expectation: These locators are preserved in salvaged_data
BAD_MANIFEST = "341dabea2bd78ad0d6fc3f5b926b450e+abc 341dabea2bd78ad0d6fc3f5b926abcdf 0:85626:brca2-hg19.fa\n. abcdabea2bd78ad0d6fc3f5b926b450e+1000 0:1000:brca-hg19.fa\n . d7321a918923627c972d8f8080c07d29+2000+A22e0a1d9b9bc85c848379d98bedc64238b0b1532@55e076ce 0:2000:brca1-hg19.fa\n"

# Mock arv_put
module SalvageCollection
  def self.salvage_collection_arv_put(cmd)
    file_contents = File.new(cmd.split[-1], "r").gets

    # simulate arv-put error when it is 'user_agreement'
    if file_contents.include? 'GNU_General_Public_License'
      raise("Error during arv-put")
    else
      ". " +
      Digest::MD5.hexdigest(TEST_MANIFEST) + "+" + TEST_MANIFEST.length.to_s +
      " 0:" + TEST_MANIFEST.length.to_s + ":invalid_manifest_text.txt\n"
    end
  end
end

class SalvageCollectionTest < ActiveSupport::TestCase
  include SalvageCollection

  setup do
    set_user_from_auth :admin
    # arv-put needs ARV env variables
    ENV['ARVADOS_API_HOST'] = 'unused_by_test'
    ENV['ARVADOS_API_TOKEN'] = 'unused_by_test'
  end

  teardown do
    ENV['ARVADOS_API_HOST'] = ''
    ENV['ARVADOS_API_TOKEN'] = ''
  end

  test "salvage test collection with valid manifest text" do
    # create a collection to test salvaging
    src_collection = Collection.new name: "test collection", manifest_text: TEST_MANIFEST
    src_collection.save!

    # salvage this collection
    SalvageCollection.salvage_collection src_collection.uuid, 'test salvage collection - see #6277, #6859'

    # verify the updated src_collection data
    updated_src_collection = Collection.find_by_uuid src_collection.uuid
    updated_name = updated_src_collection.name
    assert_equal true, updated_name.include?(src_collection.name)

    match = updated_name.match /^test collection.*salvaged data at (.*)\)$/
    assert_not_nil match
    assert_not_nil match[1]
    assert_empty updated_src_collection.manifest_text

    # match[1] is the uuid of the new collection created from src_collection's salvaged data
    # use this to get the new collection and verify
    new_collection = Collection.find_by_uuid match[1]
    match = new_collection.name.match /^salvaged from (.*),.*/
    assert_not_nil match
    assert_equal src_collection.uuid, match[1]

    # verify the new collection's manifest format
    match = new_collection.manifest_text.match /^. (.*) (.*):invalid_manifest_text.txt\n. (.*) (.*):salvaged_data/
    assert_not_nil match
  end

  test "salvage collection with no uuid required argument" do
    e = assert_raises RuntimeError do
      SalvageCollection.salvage_collection nil
    end
  end

  test "salvage collection with bogus uuid" do
    e = assert_raises RuntimeError do
      SalvageCollection.salvage_collection 'bogus-uuid'
    end
    assert_equal "No collection found for bogus-uuid.", e.message
  end

  test "salvage collection with no env ARVADOS_API_HOST" do
    e = assert_raises RuntimeError do
      ENV['ARVADOS_API_HOST'] = ''
      ENV['ARVADOS_API_TOKEN'] = ''
      SalvageCollection.salvage_collection collections('user_agreement').uuid
    end
    assert_equal "ARVADOS environment variables missing. Please set your admin user credentials as ARVADOS environment variables.", e.message
  end

  test "salvage collection with error during arv-put" do
    # try to salvage collection while mimicking error during arv-put
    e = assert_raises RuntimeError do
      SalvageCollection.salvage_collection collections('user_agreement').uuid
    end
    assert_equal "Error during arv-put", e.message
  end

  # This test uses BAD_MANIFEST, which has the following flaws:
  #   Missing stream name with locator in it's place
  #   Two invalid locators:
  #     341dabea2bd78ad0d6fc3f5b926b450e+abc
  #     341dabea2bd78ad0d6fc3f5b926b450e
  # Expectation: These locators are preserved in salvaged_data
  test "invalid locators preserved during salvaging" do
    locator_data = SalvageCollection.salvage_collection_locator_data BAD_MANIFEST
    assert_equal true, locator_data[0].size.eql?(4)
    assert_equal false, locator_data[0].include?("341dabea2bd78ad0d6fc3f5b926b450e+abc")
    assert_equal true, locator_data[0].include?("341dabea2bd78ad0d6fc3f5b926b450e")
    assert_equal true, locator_data[0].include?("341dabea2bd78ad0d6fc3f5b926abcdf")
    assert_equal true, locator_data[0].include?("abcdabea2bd78ad0d6fc3f5b926b450e+1000")
    assert_equal true, locator_data[0].include?("d7321a918923627c972d8f8080c07d29+2000")
    assert_equal true, locator_data[1].eql?(1000 + 2000)   # size
  end

  test "salvage a collection with invalid manifest text" do
    # create a collection to test salvaging
    src_collection = Collection.new name: "test collection", manifest_text: BAD_MANIFEST, owner_uuid: 'zzzzz-tpzed-000000000000000'
    src_collection.save!(validate: false)

    # salvage this collection
    SalvageCollection.salvage_collection src_collection.uuid, 'test salvage collection - see #6277, #6859'

    # verify the updated src_collection data
    updated_src_collection = Collection.find_by_uuid src_collection.uuid
    updated_name = updated_src_collection.name
    assert_equal true, updated_name.include?(src_collection.name)

    match = updated_name.match /^test collection.*salvaged data at (.*)\)$/
    assert_not_nil match
    assert_not_nil match[1]
    assert_empty updated_src_collection.manifest_text

    # match[1] is the uuid of the new collection created from src_collection's salvaged data
    # use this to get the new collection and verify
    new_collection = Collection.find_by_uuid match[1]
    match = new_collection.name.match /^salvaged from (.*),.*/
    assert_not_nil match
    assert_equal src_collection.uuid, match[1]

    # verify the new collection's manifest includes the bad locators
    match = new_collection.manifest_text.match /^. (.*) (.*):invalid_manifest_text.txt\n. (.*) (.*):salvaged_data/
    assert_not_nil match
    assert_includes(new_collection.manifest_text, ". 341dabea2bd78ad0d6fc3f5b926b450e 341dabea2bd78ad0d6fc3f5b926abcdf abcdabea2bd78ad0d6fc3f5b926b450e+1000 d7321a918923627c972d8f8080c07d29+2000 0:3000:salvaged_data")
  end
end
