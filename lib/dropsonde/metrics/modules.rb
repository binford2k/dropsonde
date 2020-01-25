class Dropsonde::Metrics::Modules
  def self.initialize_modules
    # require any libraries needed here -- no need to load puppet; it's already initialized
  end

  def self.description
    <<~EOF
      This group of metrics exports name & version information about the public
      modules installed in all environments, ignoring private modules.
    EOF
  end

  def self.schema
    # return an array of hashes of a partial schema to be merged into the complete schema
    # See https://cloud.google.com/bigquery/docs/schemas#specifying_a_json_schema_file
    [
      {
        "fields": [
          {
            "description": "The module name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
          },
          {
            "description": "The module slug (author-name)",
            "mode": "NULLABLE",
            "name": "slug",
            "type": "STRING"
          },
          {
            "description": "The module version",
            "mode": "NULLABLE",
            "name": "version",
            "type": "STRING"
          }
        ],
        "description": "List of modules in all environments.",
        "mode": "REPEATED",
        "name": "modules",
        "type": "RECORD"
      },
      {
        "fields": [
          {
            "description": "The class name",
            "mode": "NULLABLE",
            "name": "name",
            "type": "STRING"
          },
          {
            "description": "How many nodes it is declared on",
            "mode": "NULLABLE",
            "name": "count",
            "type": "INTEGER"
          }
        ],
        "description": "List of classes and counts in all environments.",
        "mode": "REPEATED",
        "name": "classes",
        "type": "RECORD"
      }
    ]
  end

  def self.setup
    # run just before generating this metric
  end

  def self.run
    # return an array of hashes representing the data to be merged into the combined checkin
    environments = Puppet.lookup(:environments).list.map{|e|e.name}
    modules = environments.map do |env|
      Puppet.lookup(:environments).get(env).modules.map do|mod|
        next unless mod.forge_module?

        {
          :name    => mod.name,
          :slug    => mod.forge_slug,
          :version => mod.version,
        }
      end
    end.flatten.compact.uniq

    if Dropsonde.puppetDB
      # classes and how many nodes they're enforced on
      results = Dropsonde.puppetDB.request( '',
        'resources[certname, type, title] { type = "Class" }'
      ).data

      # select only classes from public modules
      classes = results.map do |klass|
        next unless modules.find {|mod| mod[:name] == klass['title'].split('::').first.downcase }

        {
          :name  => klass['title'],
          :count => results.select {|row| row['title'] == klass['title']}.count,
        }
      end.compact.uniq
    else
      classes = []
    end

    [
      { :modules => modules },
      { :classes => classes },
    ]
  end

  def self.cleanup
    # run just after generating this metric
  end
end
