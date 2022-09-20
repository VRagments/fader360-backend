defmodule DarthWeb.ApiAuthControllerTest do
  use DarthWeb.ConnCase
  alias Darth.Controller.User

  setup do
    c = put_req_header(build_conn(), "accept", "application/json")
    {:ok, conn: c}
  end

  test "don't get token with invalid user", %{conn: c} do
    c = get(c, Routes.api_auth_path(c, :login), username: "some", password: "some")
    resp = json_response(c, 401)
    assert resp == "Unauthorized"
  end

  test "don't get token with missing parameters", %{conn: c} do
    c1 = get(c, Routes.api_auth_path(c, :login), [])
    resp = json_response(c1, 406)
    assert resp == "Not Acceptable"
    c2 = get(c, Routes.api_auth_path(c, :login), username: "some")
    resp = json_response(c2, 406)
    assert resp == "Not Acceptable"
  end

  test "can logout with valid user", %{conn: c} do
    c = preauth_api(c)
    c1 = post(c, Routes.api_auth_path(c, :logout))
    assert response(c1, 204)
    c2 = post(c, Routes.api_auth_path(c, :logout))
    assert response(c2, 422)
  end

  test "can refresh authentication token", %{conn: c} do
    c = preauth_api(c)

    c1 = post(c, Routes.api_auth_path(c, :refresh))
    resp = json_response(c1, 200)
    c2 = post(c, Routes.api_auth_path(c, :refresh))
    assert response(c2, 422)

    c3 =
      c
      |> put_req_header("authorization", "Bearer " <> resp["access_token"])
      |> post(Routes.api_auth_path(c, :logout))

    assert response(c3, 204)
  end

  test "can record last_logged_in_at automatically", %{conn: c} do
    pw = "testing1234"
    {:ok, user} = test_user()

    {:ok, _} =
      User.update(user.id, %{
        password: pw,
        password_confirmation: pw
      })

    c1 = get(c, Routes.api_auth_path(c, :login), username: user.username, password: pw)
    resp1 = json_response(c1, 200)
    assert resp1["last_logged_in_at"]

    c2 =
      c
      |> put_req_header("authorization", "Bearer " <> resp1["access_token"])
      |> post(Routes.api_auth_path(c, :logout))

    Process.sleep(1000)
    assert response(c2, 204)
    c3 = get(c2, Routes.api_auth_path(c, :login), username: user.username, password: pw)
    resp3 = json_response(c3, 200)
    assert resp3["last_logged_in_at"]
    assert resp1["last_logged_in_at"] != resp3["last_logged_in_at"]
  end
end
