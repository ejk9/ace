# Script to generate mock drafts for existing drafts
# Run with: mix run priv/scripts/generate_mock_drafts.exs

alias AceApp.{Drafts, MockDrafts}

# Get all existing drafts
drafts = Drafts.list_drafts()

IO.puts("Found #{length(drafts)} drafts")

# Create mock drafts for each existing draft
results = 
  Enum.map(drafts, fn draft ->
    # Check if mock draft already exists
    existing_mock_drafts = MockDrafts.list_mock_drafts_for_draft(draft.id)
    
    if existing_mock_drafts == [] do
      case MockDrafts.create_mock_draft(draft.id, %{}) do
        {:ok, mock_draft} ->
          IO.puts("✅ Created mock draft for '#{draft.name}' (ID: #{draft.id}) - Token: #{mock_draft.mock_draft_token}")
          {:created, draft, mock_draft}
        {:error, changeset} ->
          IO.puts("❌ Failed to create mock draft for '#{draft.name}' (ID: #{draft.id})")
          IO.inspect(changeset.errors)
          {:error, draft, changeset}
      end
    else
      mock_draft = hd(existing_mock_drafts)
      IO.puts("⏭️  Mock draft already exists for '#{draft.name}' (ID: #{draft.id}) - Token: #{mock_draft.mock_draft_token}")
      {:exists, draft, mock_draft}
    end
  end)

# Summary
created_count = Enum.count(results, fn {status, _, _} -> status == :created end)
existing_count = Enum.count(results, fn {status, _, _} -> status == :exists end)
error_count = Enum.count(results, fn {status, _, _} -> status == :error end)

IO.puts("\n📊 Summary:")
IO.puts("  - Created: #{created_count}")
IO.puts("  - Already existed: #{existing_count}")
IO.puts("  - Errors: #{error_count}")

if created_count > 0 or existing_count > 0 do
  IO.puts("\n🔗 Mock Draft Links Available:")
  
  Enum.each(results, fn
    {status, draft, mock_draft} when status in [:created, :exists] ->
      IO.puts("\n  Draft: #{draft.name}")
      IO.puts("    Pre-draft: /mock-drafts/#{mock_draft.mock_draft_token}/predraft")
      IO.puts("    Live:      /mock-drafts/#{mock_draft.mock_draft_token}/live")
      IO.puts("    Leaderboard: /mock-drafts/#{mock_draft.mock_draft_token}/leaderboard")
    _ -> 
      :ok
  end)
end

IO.puts("\n✨ Done! Check your draft links pages to see the new mock draft sections.")