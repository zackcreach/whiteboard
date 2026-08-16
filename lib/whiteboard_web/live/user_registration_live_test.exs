defmodule WhiteboardWeb.UserRegistrationLiveTest do
  use WhiteboardWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Whiteboard.AccountsFixtures

  alias Whiteboard.Accounts

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Register"
      assert html =~ "Log in"
      refute html =~ "data-size="
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      assert result =~ "Register"
      assert result =~ "must have the @ sign and no spaces"
      assert result =~ "should be at least 12 character"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()
      user_attributes = valid_user_attributes(email: email)
      form = form(lv, "#registration_form", user: user_attributes)
      result = render_submit(form)
      assert_receive {:email, email_message}
      assert {"Whiteboard", "mailer@mg.zackcrea.ch"} == email_message.from
      assert [{"", ^email}] = email_message.to
      assert email_message.text_body =~ "/users/confirm/"
      assert result =~ ~s(value="#{user_attributes.password}")

      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/workouts"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ "Dashboard"
      assert response =~ "Workouts"
      assert response =~ "Settings"
      refute response =~ "Logout"
    end

    test "shows a retryable error when confirmation delivery fails", %{conn: conn} do
      mailer_config = Application.fetch_env!(:whiteboard, Whiteboard.Mailer)
      Application.put_env(:whiteboard, Whiteboard.Mailer, adapter: Whiteboard.FailingMailerAdapter)
      on_exit(fn -> Application.put_env(:whiteboard, Whiteboard.Mailer, mailer_config) end)

      {:ok, lv, _html} = live(conn, ~p"/users/register")
      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      assert render_submit(form) =~
               "We couldn&#39;t send your confirmation email. Please try again in a moment."

      assert nil == Accounts.get_user_by_email(email)

      Application.put_env(:whiteboard, Whiteboard.Mailer, mailer_config)
      render_submit(form)

      assert_receive {:email, %{to: [{"", ^email}]}}
      assert %Accounts.User{email: ^email} = Accounts.get_user_by_email(email)
    end

    test "renders errors for duplicated email", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      user = user_fixture(%{email: "test@email.com"})

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "valid_password"}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element(~s|main a[href="#{~p"/users/log_in"}"]|)
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log_in")

      assert login_html =~ "Log in"
    end
  end
end
