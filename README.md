# Auto Link Related Issues Plugin

This plugin automatically links related issues in Redmine when internal issue links (e.g., `#123`) are mentioned in comments.

## Installation

1. Clone this repository into your Redmine `plugins` directory:
   ```bash
   git clone http://github.com/unchained-llc/redmine_auto_link_relate.git plugins/redmine_auto_link_relate
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Restart your Redmine instance.

4. Verify that the plugin is installed under **Administration > Plugins**.

## Usage

### Automatic Linking
When a user adds a comment containing an internal issue link (e.g., `#123`), this plugin automatically creates a relation between the current issue and the linked issue.

### Bulk Processing of Existing Comments
You can use the provided Rake task to scan all existing comments and link issues retroactively.

#### Running the Rake Task
**Warning:** This task may modify your database in unexpected ways. Always back up your data before running it.

1. Create a backup of your database:
   ```bash
   pg_dump redmine > redmine_backup.sql  # For PostgreSQL
   mysqldump redmine > redmine_backup.sql  # For MySQL
   ```

2. Run the task:
   ```bash
   bundle exec rake redmine_auto_link_relate:relate_issues RAILS_ENV=production
   ```

3. Monitor the output:
   - Existing relations and invalid operations are skipped.
   - Details of newly created relations are logged to the console.

#### What the Task Does
- Scans all comments in your Redmine instance.
- Extracts internal issue links (e.g., `#123`) from the comments.
- Creates relations between issues where appropriate.

#### Skipping Conditions
The Rake task skips creating relations in the following cases:
- The relation already exists.
- The relation would cause a circular dependency.
- The issues are in a parent-child relationship.
- Other relationships (e.g., `duplicates`, `blocks`, `precedes`) already exist between the issues.

## Development

To contribute:
1. Fork the repository.
2. Create a new branch for your changes.
3. Submit a pull request with a clear description of your changes.

## License

This plugin is licensed under the MIT License. See [LICENSE](LICENSE) for details.

