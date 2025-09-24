defmodule AceApp.FilesTest do
  use AceApp.DataCase

  alias AceApp.Files
  alias AceApp.Files.FileUpload
  alias AceApp.Drafts

  describe "file_uploads" do
    setup do
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft",
        format: :snake,
        pick_timer_seconds: 60
      })
      
      %{draft: draft}
    end

    test "create_file_upload/1 with valid data creates a file upload", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, %FileUpload{} = file_upload} = Files.create_file_upload(valid_attrs)
      assert file_upload.filename == "test_logo.png"
      assert file_upload.content_type == "image/png"
      assert file_upload.file_size == 1024
      assert file_upload.upload_status == "completed"
      assert file_upload.file_type == "team_logo"
    end

    test "create_file_upload/1 with WebP format is valid", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.webp",
        content_type: "image/webp",
        file_size: 2048,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.webp",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, %FileUpload{} = file_upload} = Files.create_file_upload(valid_attrs)
      assert file_upload.content_type == "image/webp"
      assert file_upload.filename == "test_logo.webp"
    end

    test "create_file_upload/1 with 10MB file size is valid", %{draft: draft} do
      max_size = 10_485_760  # 10MB

      valid_attrs = %{
        draft_id: draft.id,
        filename: "large_logo.png",
        content_type: "image/png",
        file_size: max_size,
        file_path: "/uploads/drafts/#{draft.id}/logos/large_logo.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, %FileUpload{} = file_upload} = Files.create_file_upload(valid_attrs)
      assert file_upload.file_size == max_size
    end

    test "create_file_upload/1 with file size over 10MB fails", %{draft: draft} do
      over_max_size = 10_485_761  # 10MB + 1 byte

      invalid_attrs = %{
        draft_id: draft.id,
        filename: "too_large.png",
        content_type: "image/png",
        file_size: over_max_size,
        file_path: "/uploads/drafts/#{draft.id}/logos/too_large.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:error, %Ecto.Changeset{}} = Files.create_file_upload(invalid_attrs)
    end

    test "create_file_upload/1 with invalid content type fails", %{draft: draft} do
      invalid_attrs = %{
        draft_id: draft.id,
        filename: "test.txt",
        content_type: "text/plain",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test.txt",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:error, %Ecto.Changeset{}} = Files.create_file_upload(invalid_attrs)
    end

    test "create_file_upload/1 with invalid data returns error changeset", %{draft: draft} do
      invalid_attrs = %{
        draft_id: draft.id,
        filename: "",
        content_type: "",
        file_size: nil,
        file_path: "",
        upload_status: "invalid",
        file_type: ""
      }

      assert {:error, %Ecto.Changeset{}} = Files.create_file_upload(invalid_attrs)
    end

    test "get_file_upload!/1 returns the file upload with given id", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      {:ok, file_upload} = Files.create_file_upload(valid_attrs)
      assert Files.get_file_upload!(file_upload.id) == file_upload
    end

    test "mark_upload_completed/1 updates upload status", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.png",
        upload_status: "uploading",
        file_type: "team_logo"
      }

      {:ok, file_upload} = Files.create_file_upload(valid_attrs)
      {:ok, updated_upload} = Files.mark_upload_completed(file_upload.id)
      
      assert updated_upload.upload_status == "completed"
    end

    test "mark_upload_failed/1 updates upload status", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.png",
        upload_status: "uploading",
        file_type: "team_logo"
      }

      {:ok, file_upload} = Files.create_file_upload(valid_attrs)
      {:ok, updated_upload} = Files.mark_upload_failed(file_upload.id)
      
      assert updated_upload.upload_status == "failed"
    end

    test "delete_file_upload/1 deletes the file upload", %{draft: draft} do
      valid_attrs = %{
        draft_id: draft.id,
        filename: "test_logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/test_logo.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      {:ok, file_upload} = Files.create_file_upload(valid_attrs)
      assert {:ok, %FileUpload{}} = Files.delete_file_upload(file_upload)
      assert_raise Ecto.NoResultsError, fn -> Files.get_file_upload!(file_upload.id) end
    end
  end

  describe "allowed content types" do
    setup do
      {:ok, draft} = Drafts.create_draft(%{
        name: "Test Draft",
        format: :snake,
        pick_timer_seconds: 60
      })
      
      %{draft: draft}
    end

    test "PNG files are accepted", %{draft: draft} do
      attrs = %{
        draft_id: draft.id,
        filename: "logo.png",
        content_type: "image/png",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/logo.png",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, _file_upload} = Files.create_file_upload(attrs)
    end

    test "JPEG files are accepted", %{draft: draft} do
      attrs = %{
        draft_id: draft.id,
        filename: "logo.jpg",
        content_type: "image/jpeg",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/logo.jpg",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, _file_upload} = Files.create_file_upload(attrs)
    end

    test "SVG files are accepted", %{draft: draft} do
      attrs = %{
        draft_id: draft.id,
        filename: "logo.svg",
        content_type: "image/svg+xml",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/logo.svg",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, _file_upload} = Files.create_file_upload(attrs)
    end

    test "WebP files are accepted", %{draft: draft} do
      attrs = %{
        draft_id: draft.id,
        filename: "logo.webp",
        content_type: "image/webp",
        file_size: 1024,
        file_path: "/uploads/drafts/#{draft.id}/logos/logo.webp",
        upload_status: "completed",
        file_type: "team_logo"
      }

      assert {:ok, _file_upload} = Files.create_file_upload(attrs)
    end
  end
end