/*
# Copyright 2019-2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0
*/
#ifndef	__DMRLOOKUP__
#define	__DMRLOOKUP__

#include "DMRId.hpp"
#include <string>
// #include <unordered_map>
#include <vector>
#include <utility>

using namespace std;

class CDMRLookup {
public:
	CDMRLookup(const string& filename);
	virtual ~CDMRLookup();

	bool read();
	bool append(const string& filename);

	string findCallsign(string uid);
	user_t findUser(string uid);

private:
	string m_file_dmrid;

	// unordered_map<unsigned int, string> m_table;
	vector<pair<unsigned int, string> > m_vtable;

	bool load();
};

#endif
