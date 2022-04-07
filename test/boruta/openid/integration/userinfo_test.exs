defmodule Boruta.OpenidTest.UserinfoTest do
  use Boruta.DataCase
  import Plug.Conn

  import Boruta.Factory
  import Mox

  alias Boruta.Ecto.Token
  alias Boruta.Oauth.ResourceOwner
  alias Boruta.Openid
  alias Boruta.Openid.ApplicationMock

  setup :verify_on_exit!

  describe "fetch userinfo" do
    test "returns unauthorized with no bearer token" do
      conn = %Plug.Conn{}

      assert {:unauthorized,
              %Boruta.Oauth.Error{
                error: :invalid_bearer,
                error_description: "Invalid bearer from Authorization header.",
                status: :bad_request
              }} = Openid.userinfo(conn, ApplicationMock)
    end

    test "returns unauthorized with a bad authorization header" do
      conn =
        %Plug.Conn{}
        |> put_req_header("authorization", "not a bearer")

      assert {:unauthorized,
              %Boruta.Oauth.Error{
                error: :invalid_bearer,
                error_description: "Invalid bearer from Authorization header.",
                status: :bad_request
              }} = Openid.userinfo(conn, ApplicationMock)
    end

    test "returns unauthorized with a bad access token" do
      conn =
        %Plug.Conn{}
        |> put_req_header("authorization", "Bearer bad_token")

      assert {:unauthorized,
              %Boruta.Oauth.Error{
                error: :invalid_access_token,
                error_description: "Provided access token is invalid.",
                status: :bad_request
              }} = Openid.userinfo(conn, ApplicationMock)
    end

    test "returns an error when token does not belong to a resource owner" do
      %Token{value: access_token} = insert(:token)

      conn =
        %Plug.Conn{}
        |> put_req_header("authorization", "Bearer #{access_token}")

      assert {:unauthorized,
              %Boruta.Oauth.Error{
                error: :invalid_bearer,
                error_description: "Invalid bearer from Authorization header.",
                status: :bad_request
              }} = Openid.userinfo(conn, ApplicationMock)
    end

    test "returns userinfo" do
      sub = SecureRandom.uuid()
      claims = %{"claim" => true}
      %Token{value: access_token} = insert(:token, sub: sub)

      conn =
        %Plug.Conn{}
        |> put_req_header("authorization", "Bearer #{access_token}")

      expect(Boruta.Support.ResourceOwners, :get_by, fn sub: ^sub ->
        {:ok, %ResourceOwner{sub: sub}}
      end)

      expect(Boruta.Support.ResourceOwners, :claims, fn %ResourceOwner{sub: ^sub}, _scope ->
        claims
      end)

      assert {:userinfo_fetched,
              %{:sub => ^sub, "claim" => true}} =
               Openid.userinfo(conn, ApplicationMock)
    end
  end
end
