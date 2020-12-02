box.cfg{listen = 3301, memtx_memory = 10 * 1024^3}
box.schema.user.grant('guest', 'read,write,execute', 'universe', nil, { if_not_exists = true })
