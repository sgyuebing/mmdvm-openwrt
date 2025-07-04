/*
# Copyright 2019-2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0
*/

#include "DMRLookup.hpp"
#include <assert.h>
#include <iostream>

using namespace std;

#ifdef __cplusplus
  #include "lua.hpp"
#else
  #include "lua.h"
  #include "lualib.h"
  #include "lauxlib.h"
#endif

static CDMRLookup* m_lookup = NULL;

string findCallsignByUID(string uid) {
    assert(m_lookup != NULL);
    return m_lookup->findCallsign(uid);
}

user_t findUserByUID(string uid) {
    assert(m_lookup != NULL);
    return m_lookup->findUser(uid);
}

void load(string dmrid_file) {
    if(m_lookup == NULL) {
        m_lookup = new CDMRLookup(dmrid_file);
        m_lookup->read();
    }
}

void app(string dmrid_file) {
    if(m_lookup != NULL) {
        m_lookup->append(dmrid_file);
    }
}

// int main() {
//     load("/Users/mic/Work/radioid/export/DMRIds.dat");
//     string callsign = "BD7MQB";
//     // cout << m_lookup->find(callsign) << endl;
//     user_t user = m_lookup->findUser(callsign);
//     cout << "ID:\t\t" << user.id << endl;
//     cout << "Name:\t\t" << user.name << endl;
//     cout << "City:\t\t" << user.city << endl;
//     cout << "Country:\t" << user.country << endl;
//     return 0;
// }

//so that name mangling doesn't mess up function names
#ifdef __cplusplus
extern "C"{
#endif

static int init (lua_State *L) {
    const char *dmrid_file;
    dmrid_file = luaL_checkstring(L, 1);
    load(string(dmrid_file));
    const char *dmrid_file1;
    dmrid_file1 = luaL_checkstring(L, 2);
    app(string(dmrid_file1));

    return 0;
}

static int get_callsign_by_uid (lua_State *L) {
    const char *uid;
    uid = luaL_checkstring(L, 1);
    string cs = findCallsignByUID(string(uid));
    lua_pushstring(L, cs.c_str());

    return 1;
}

static int get_user_by_uid (lua_State *L) {
    const char *uid;
    uid = luaL_checkstring(L, 1);

    user_t user = findUserByUID(string(uid));

    if (!user.exist()) {
        return 0;
    }
    
    lua_createtable(L, 0, 3);

    lua_pushstring(L, user.callsign.c_str());
    lua_setfield(L, -2, "callsign");
    lua_pushstring(L, user.name.c_str());
    lua_setfield(L, -2, "name");
    lua_pushstring(L, user.country.c_str());
    lua_setfield(L, -2, "country");

    return 1;
}

//library to be registered
static const struct luaL_Reg mylib [] = {
        {"get_callsign_by_uid", get_callsign_by_uid},
        {"get_user_by_uid", get_user_by_uid},
        {"init", init},
        {NULL, NULL}  /* sentinel */
};

int luaopen_mmdvm(lua_State *L) {
#ifdef OPENWRT
    // Lua 5.1 style
    luaL_register(L, "mmdvm", mylib);
#else
    // Lua 5.3 style
    luaL_newlib(L, mylib);
#endif
	return 1;
}

#ifdef __cplusplus
}
#endif
