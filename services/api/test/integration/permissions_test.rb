# Copyright (C) The Arvados Authors. All rights reserved.
#
# SPDX-License-Identifier: AGPL-3.0

require 'test_helper'

class PermissionsTest < ActionDispatch::IntegrationTest
  include DbCurrentTime
  fixtures :users, :groups, :api_client_authorizations, :collections

  test "adding and removing direct can_read links" do
    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # try to add permission as spectator
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: collections(:foo_file).uuid,
          properties: {}
        }
      },
      headers: auth(:spectator)
    assert_response 422

    # add permission as admin
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: collections(:foo_file).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    u = json_response['uuid']
    assert_response :success

    # read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response :success

    # try to delete permission as spectator
    delete "/arvados/v1/links/#{u}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 403

    # delete permission as admin
    delete "/arvados/v1/links/#{u}",
      params: {:format => :json},
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404
  end


  test "adding can_read links from user to group, group to collection" do
    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # add permission for spectator to read group
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:private_role).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # add permission for group to read collection
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: groups(:private_role).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: collections(:foo_file).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    u = json_response['uuid']
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response :success

    # delete permission for group to read collection
    delete "/arvados/v1/links/#{u}",
      params: {:format => :json},
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

  end


  test "adding can_read links from group to collection, user to group" do
    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # add permission for group to read collection
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: groups(:private_role).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: collections(:foo_file).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # add permission for spectator to read group
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:private_role).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    u = json_response['uuid']
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response :success

    # delete permission for spectator to read group
    delete "/arvados/v1/links/#{u}",
      params: {:format => :json},
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

  end

  test "adding can_read links from user to group, group to group, group to collection" do
    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404

    # add permission for user to read group
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:private_role).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success

    # add permission for group to read group
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: groups(:private_role).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:empty_lonely_group).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success

    # add permission for group to read collection
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: groups(:empty_lonely_group).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: collections(:foo_file).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    u = json_response['uuid']
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response :success

    # delete permission for group to read collection
    delete "/arvados/v1/links/#{u}",
      params: {:format => :json},
      headers: auth(:admin)
    assert_response :success

    # try to read collection as spectator
    get "/arvados/v1/collections/#{collections(:foo_file).uuid}",
      params: {:format => :json},
      headers: auth(:spectator)
    assert_response 404
  end

  test "read-only group-admin cannot modify administered user" do
    put "/arvados/v1/users/#{users(:active).uuid}",
      params: {
        :user => {
          first_name: 'KilroyWasHere'
        },
        :format => :json
      },
      headers: auth(:rominiadmin)
    assert_response 403
  end

  test "read-only group-admin cannot read or update non-administered user" do
    get "/arvados/v1/users/#{users(:spectator).uuid}",
      params: {:format => :json},
      headers: auth(:rominiadmin)
    assert_response 404

    put "/arvados/v1/users/#{users(:spectator).uuid}",
      params: {
        :user => {
          first_name: 'KilroyWasHere'
        },
        :format => :json
      },
      headers: auth(:rominiadmin)
    assert_response 404
  end

  test "RO group-admin finds user's specimens, RW group-admin can update" do
    [[:rominiadmin, false],
     [:miniadmin, true]].each do |which_user, update_should_succeed|
      get "/arvados/v1/specimens",
        params: {:format => :json},
        headers: auth(which_user)
      assert_response :success
      resp_uuids = json_response['items'].collect { |i| i['uuid'] }
      [[true, specimens(:owned_by_active_user).uuid],
       [true, specimens(:owned_by_private_group).uuid],
       [false, specimens(:owned_by_spectator).uuid],
      ].each do |should_find, uuid|
        assert_equal(should_find, !resp_uuids.index(uuid).nil?,
                     "%s should%s see %s in specimen list" %
                     [which_user.to_s,
                      should_find ? '' : 'not ',
                      uuid])
        put "/arvados/v1/specimens/#{uuid}",
          params: {
            :specimen => {
              properties: {
                miniadmin_was_here: true
              }
            },
            :format => :json
          },
          headers: auth(which_user)
        if !should_find
          assert_response 404
        elsif !update_should_succeed
          assert_response 403
        else
          assert_response :success
        end
      end
    end
  end

  test "get_permissions returns list" do
    # First confirm that user :active cannot get permissions on group :public
    get "/arvados/v1/permissions/#{groups(:public).uuid}",
      params: nil,
      headers: auth(:active)
    assert_response 404

    get "/arvados/v1/links",
        params: {
          :filters => [["link_class", "=", "permission"], ["head_uuid", "=", groups(:public).uuid]].to_json
        },
      headers: auth(:active)
    assert_response :success
    assert_equal [], json_response['items']

    ### add some permissions, including can_manage
    ### permission for user :active
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:spectator).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:public).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success
    can_read_uuid = json_response['uuid']

    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:inactive).uuid,
          link_class: 'permission',
          name: 'can_write',
          head_uuid: groups(:public).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success
    can_write_uuid = json_response['uuid']

    # Still should not be able read these permission links
    get "/arvados/v1/permissions/#{groups(:public).uuid}",
      params: nil,
      headers: auth(:active)
    assert_response 404

    get "/arvados/v1/links",
        params: {
          :filters => [["link_class", "=", "permission"], ["head_uuid", "=", groups(:public).uuid]].to_json
        },
      headers: auth(:active)
    assert_response :success
    assert_equal [], json_response['items']

    # Shouldn't be able to read links directly either
    get "/arvados/v1/links/#{can_read_uuid}",
        params: {},
      headers: auth(:active)
    assert_response 404

    ### Now add a can_manage link
    post "/arvados/v1/links",
      params: {
        :format => :json,
        :link => {
          tail_uuid: users(:active).uuid,
          link_class: 'permission',
          name: 'can_manage',
          head_uuid: groups(:public).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success
    can_manage_uuid = json_response['uuid']

    # user :active should be able to retrieve permissions
    # on group :public using get_permissions
    get("/arvados/v1/permissions/#{groups(:public).uuid}",
      params: { :format => :json },
      headers: auth(:active))
    assert_response :success

    perm_uuids = json_response['items'].map { |item| item['uuid'] }
    assert_includes perm_uuids, can_read_uuid, "can_read_uuid not found"
    assert_includes perm_uuids, can_write_uuid, "can_write_uuid not found"
    assert_includes perm_uuids, can_manage_uuid, "can_manage_uuid not found"

    # user :active should be able to retrieve permissions
    # on group :public using link list
    get "/arvados/v1/links",
        params: {
          :filters => [["link_class", "=", "permission"], ["head_uuid", "=", groups(:public).uuid]].to_json
        },
      headers: auth(:active)
    assert_response :success

    perm_uuids = json_response['items'].map { |item| item['uuid'] }
    assert_includes perm_uuids, can_read_uuid, "can_read_uuid not found"
    assert_includes perm_uuids, can_write_uuid, "can_write_uuid not found"
    assert_includes perm_uuids, can_manage_uuid, "can_manage_uuid not found"

    # Should be able to read links directly too
    get "/arvados/v1/links/#{can_read_uuid}",
        params: {},
      headers: auth(:active)
    assert_response :success

    ### Now delete the can_manage link
    delete "/arvados/v1/links/#{can_manage_uuid}",
      params: nil,
      headers: auth(:active)
    assert_response :success

    # Should not be able read these permission links again
    get "/arvados/v1/permissions/#{groups(:public).uuid}",
      params: nil,
      headers: auth(:active)
    assert_response 404

    get "/arvados/v1/links",
        params: {
          :filters => [["link_class", "=", "permission"], ["head_uuid", "=", groups(:public).uuid]].to_json
        },
      headers: auth(:active)
    assert_response :success
    assert_equal [], json_response['items']

    # Should not be able to read links directly either
    get "/arvados/v1/links/#{can_read_uuid}",
        params: {},
      headers: auth(:active)
    assert_response 404
  end

  test "get_permissions returns 404 for nonexistent uuid" do
    nonexistent = Group.generate_uuid
    # make sure it really doesn't exist
    get "/arvados/v1/groups/#{nonexistent}", params: nil, headers: auth(:admin)
    assert_response 404

    get "/arvados/v1/permissions/#{nonexistent}", params: nil, headers: auth(:active)
    assert_response 404
  end

  test "get_permissions returns 403 if user can read but not manage" do
    post "/arvados/v1/links",
      params: {
        :link => {
          tail_uuid: users(:active).uuid,
          link_class: 'permission',
          name: 'can_read',
          head_uuid: groups(:public).uuid,
          properties: {}
        }
      },
      headers: auth(:admin)
    assert_response :success

    get "/arvados/v1/permissions/#{groups(:public).uuid}",
      params: nil,
      headers: auth(:active)
    assert_response 403
  end

  test "active user can read the empty collection" do
    # The active user should be able to read the empty collection.

    get("/arvados/v1/collections/#{empty_collection_pdh}",
      params: {:format => :json},
      headers: auth(:active))
    assert_response :success
    assert_empty json_response['manifest_text'], "empty collection manifest_text is not empty"
  end
end
