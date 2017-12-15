module Git
  class Commit
    attr_accessor :message, :author, :date, :hash

    def initialize(message, author, date, hash)
      @message = message
      @author = author
      @date = date
      @hash = hash
    end
  end
end
