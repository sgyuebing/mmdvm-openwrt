/*
# Copyright 2019-2020 Michael BD7MQB <bd7mqb@qq.com>
# This is free software, licensed under the GNU GENERAL PUBLIC LICENSE, Version 2.0
*/
#include "DMRLookup.hpp"
#include "Utils.hpp"
#include "DMRId.hpp"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <algorithm>

using namespace std;
using namespace utils;

bool compareByFirst(const std::pair<unsigned int, std::string>& a,
                    const std::pair<unsigned int, std::string>& b) {
    return a.first < b.first;
}

std::vector<std::pair<unsigned int, std::string>>::iterator find(
    std::vector<std::pair<unsigned int, std::string>>& sorted_vec,
    unsigned int key) {

    auto it = std::lower_bound(sorted_vec.begin(), sorted_vec.end(), key, [](std::pair<unsigned int, std::string>& pair, unsigned int key) {
        return pair.first < key;
    });

    if (it != sorted_vec.end() && it->first == key) {
        return it;
    }

    return sorted_vec.end();
}

CDMRLookup::CDMRLookup(const string& filename) :
m_file_dmrid(filename),
m_vtable()
{
}

CDMRLookup::~CDMRLookup() {
	delete this;
}

bool CDMRLookup::read() {
	bool ret = load();
	return ret;
}

string CDMRLookup::findCallsign(string uid) {
	string callsign = uid;
	unsigned int id = 0;
	try {
	    id = (unsigned int)::atoi(uid.c_str());
	} catch (...) {
	    id = 0;
	}
	try {
		auto it = find(m_vtable, id);
		if (it == m_vtable.end()) {
			return callsign;
		}
		std::string line = it->second;
		char buffer[150U];
		::strcpy(buffer, line.c_str());
		char* s = buffer;
		char* p1 = ::strsep(&s, "\t");
		if (p1 != NULL) {
			callsign = string(p1);
		}
	} catch (...) {
	}
	return callsign;
}

user_t CDMRLookup::findUser(string uid) {
	user_t user;
	user.callsign = uid;
	unsigned int id = 0;
	try {
	    id = (unsigned int)::atoi(uid.c_str());
	} catch (...) {
	    id = 0;
	}
	try {
		auto it = find(m_vtable, id);
		if (it == m_vtable.end()) {
			return user;
		}
		std::string line = it->second;
		char buffer[150U];
		::strcpy(buffer, line.c_str());
		char* s = buffer;
		char* p1 = ::strsep(&s, "\t");
		char* p2 = ::strsep(&s, "\t");
		char* p3 = ::strsep(&s, "\t");

		if (p1 != NULL) {
			user.callsign = string(p1);
		}
		if (p2 != NULL) {
			user.name = string(p2);
		 }
		if (p3 != NULL) {
			user.country = rtrim(string(p3));
		}
	} catch (...) {
	}
	return user;
}


bool CDMRLookup::load() {
	FILE* fp = ::fopen(m_file_dmrid.c_str(), "rt");
	if (fp == NULL) {
		printf("Cannot open the DMR Id lookup file - %s\n", m_file_dmrid.c_str());
		return false;
	}

	m_vtable.clear();

	char buffer[150U];

	while (::fgets(buffer, 150U, fp) != NULL) {
		if (buffer[0U] == '#')
			continue;
		char* s = buffer;
		char* p1 = ::strsep(&s, " \t");
		if (p1 != NULL) {
			unsigned int id = 0;
			try {
			    id = (unsigned int)::atoi(p1);
			    m_vtable.emplace_back(id, string(s));
			} catch (...) {
			    id = 0;
			}
		}
	}

	::fclose(fp);

	size_t size = m_vtable.size();
	if (size == 0U)
		return false;

	return true;
}


bool CDMRLookup::append(const string & filename) {
	FILE* fp = ::fopen(filename.c_str(), "rt");
	if (fp == NULL) {
		printf("Cannot open the DMR Id lookup file - %s\n", filename.c_str());
		return false;
	}
        size_t sz = m_vtable.size();

	char buffer[150U];
	auto it = m_vtable.begin();

	while (::fgets(buffer, 150U, fp) != NULL) {
		if (buffer[0U] == '#')
			continue;
		char* s = buffer;
		char* p1 = ::strsep(&s, " \t");
		if (p1 != NULL) {
			unsigned int id = 0;
			try {
				id = (unsigned int)::atoi(p1);
				it = std::lower_bound(it, m_vtable.end(), id, [](std::pair<unsigned int, std::string>& pair, unsigned int key) {
				        return pair.first < key;
				    });
				if (it == m_vtable.end() || it->first != id ) {
					it = m_vtable.emplace(it, id, std::string(s));
				} else {
					it->second = string(s);
				}
			} catch (...) {
			    id = 0;
			}
		}
	}

	::fclose(fp);

	size_t size = m_vtable.size();
	if (size == sz )
		return false;
	return true;
}

			
