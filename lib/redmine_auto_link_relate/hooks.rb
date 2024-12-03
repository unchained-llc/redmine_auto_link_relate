module RedmineAutoLinkRelate
  class Hooks < Redmine::Hook::Listener
    def controller_issues_edit_after_save(context = {})
      journal = context[:journal]
      return unless journal

      issue = journal.journalized
      return unless issue.is_a?(Issue)

      related_issue_ids = extract_issue_ids(journal.notes)
      related_issue_ids.each do |related_issue_id|
        related_issue = Issue.find_by_id(related_issue_id)
        next unless related_issue

        # Check if the relation already exists
        unless IssueRelation.exists?(issue_from_id: issue.id, issue_to_id: related_issue.id)
          IssueRelation.create!(issue_from: issue, issue_to: related_issue, relation_type: 'relates')
        end
      end
    end

    private

    def extract_issue_ids(notes)
      return [] if notes.blank?

      notes.scan(/#(\d+)/).flatten.map(&:to_i)
    end
  end
end
