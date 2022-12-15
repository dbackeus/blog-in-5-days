require "pstore"

class PStoreAdapter
  def initialize
    @store = PStore.new("db/test.store", false)
  end

  def read
    @store.transaction(true) { @store["posts"] }
  end

  def write(data)
    @store.transaction do
      @store["posts"] = data
    end
  end
end
