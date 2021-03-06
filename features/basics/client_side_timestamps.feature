Feature: Client-side Timestamps

  Cassandra 2.1 introduced client-side timestamps. Client-side timestamps can
  be used to provide Cassandra with a client-side timestamp for database operations,
  rather than have it generated server-side. When this is enabled, it helps to
  mitigate Cassandra cluster clock skew, but may introduce application cluster
  clock skew as the client timestamp is used.

  @cassandra-version-specific @cassandra-version-2.1
  Scenario: Using client-side timestamps
    Given a running cassandra cluster with schema:
    """cql
      CREATE KEYSPACE simplex WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 3};
      CREATE TABLE simplex.users (
        user_id BIGINT PRIMARY KEY,
        first VARCHAR,
        last VARCHAR,
        age INT
      );
      """
    And the following example:
    """ruby
      require 'cassandra'
      require 'delorean'

      # Enable client-side timestamps. Valid values:
      # nil / false : don't enable client-side timestamps. This is the default.
      # true : enable client-side timestamps and use the default timestamp generator for the Ruby flavor being used:
      #     JRuby - Cassandra::TimestampGenerator::TickingOnDuplicate
      #     MRI/Rubinius - Cassandra::TimestampGenerator::Simple
      # :simple : enable client-side timestamps and use a Cassandra::TimestampGenerator::Simple generator.
      # :monotonic : enable client-side timestamps and use a Cassandra::TimestampGenerator::TickingOnDuplicate generator.

      cluster = Cassandra.cluster(client_timestamps: :simple)
      session = cluster.connect("simplex")

      # Insert in the present
      session.execute("INSERT INTO users (user_id, first, last, age) VALUES (0, 'John', 'Doe', 40)", consistency: :all)

      # Set current time to the past, old client-side timestamp won't update the row
      Delorean.time_travel_to "1 minute ago" do
        # Simple statements
        session.execute("INSERT INTO users (user_id, first, last, age) VALUES (0, 'Mary', 'Holler', 22)", consistency: :all)
        row = session.execute("SELECT * FROM users WHERE user_id = 0").first
        puts "#{row["first"]} #{row["last"]} / #{row["age"]}"

        # Prepared statements
        insert = session.prepare("INSERT INTO users (user_id, first, last, age) VALUES (?, ?, ?, ?)")
        session.execute(insert, arguments: [0, 'Jane', 'Smith', 30], consistency: :all)
        row = session.execute("SELECT * FROM users WHERE user_id = 0").first
        puts "#{row["first"]} #{row["last"]} / #{row["age"]}"

        # Batch statements
        batch = session.batch do |b|
          b.add(insert, arguments: [0, 'Ruby', 'Driver', 2])
        end
        session.execute(batch, consistency: :all)
        row = session.execute("SELECT * FROM users WHERE user_id = 0").first
        puts "#{row["first"]} #{row["last"]} / #{row["age"]}"
      end
      """
    When it is executed
    Then its output should contain:
      """
      John Doe / 40
      John Doe / 40
      John Doe / 40
      """
