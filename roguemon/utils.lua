local utils = {}

-- Compare two SemVer strings
-- Returns -1 if v1 is older than v2, 1 if v1 is newer than v2.
-- Example evaluation of pre-release labels:
-- 1.0.0-alpha < 1.0.0-alpha.1 < 1.0.0-alpha.beta < 1.0.0-beta < 1.0.0-beta.2 < 1.0.0-beta.11 < 1.0.0-rc.1 < 1.0.0
function utils.compare_semver(v1, v2)
    -- Parse versions
    local function parse_semver(version)
        local major, minor, patch, prerelease, build = version:match("^(%d+)%.(%d+)%.(%d+)(%-?[%w%-%.]*)(%+?[%w%.%-]*)")
        if not prerelease:find("^%-") then
            prerelease = ""
        end
        if not build:find("^%+") then
            build = ""
        end
        prerelease = prerelease ~= "" and prerelease or nil
        build = build ~= "" and build or nil
        return {
            major = tonumber(major),
            minor = tonumber(minor),
            patch = tonumber(patch),
            prerelease = prerelease and prerelease:sub(2) or nil, -- Remove '-' prefix
            build = build and build:sub(2) or nil                 -- Remove '+' prefix
        }
    end

    local v1_parts = parse_semver(v1)
    local v2_parts = parse_semver(v2)

    -- Compare major, minor, patch
    if v1_parts.major ~= v2_parts.major then
        return v1_parts.major > v2_parts.major and 1 or -1
    end
    if v1_parts.minor ~= v2_parts.minor then
        return v1_parts.minor > v2_parts.minor and 1 or -1
    end
    if v1_parts.patch ~= v2_parts.patch then
        return v1_parts.patch > v2_parts.patch and 1 or -1
    end

    -- Compare prerelease (if one has a prerelease and the other doesn't, the one without is newer)
    if v1_parts.prerelease == nil and v2_parts.prerelease == nil then
        return 0
    elseif v1_parts.prerelease == nil then
        return 1
    elseif v2_parts.prerelease == nil then
        return -1
    end

    -- Split prerelease into components
    local function split_prerelease(prerelease)
        local components = {}
        for part in prerelease:gmatch("[^%.]+") do
            table.insert(components, part)
        end
        return components
    end

    local v1_prerelease = split_prerelease(v1_parts.prerelease)
    local v2_prerelease = split_prerelease(v2_parts.prerelease)

    -- Compare each prerelease component
    for i = 1, math.max(#v1_prerelease, #v2_prerelease) do
        local c1 = v1_prerelease[i]
        local c2 = v2_prerelease[i]

        -- If one component is missing, the shorter one is older
        if c1 == nil and c2 == nil then
            return 0
        elseif c1 == nil then
            return -1
        elseif c2 == nil then
            return 1
        end

        -- Compare numeric vs alphanumeric components
        local c1_num = tonumber(c1)
        local c2_num = tonumber(c2)

        if c1_num ~= nil and c2_num ~= nil then -- Both numeric
            if c1_num ~= c2_num then
                return c1_num > c2_num and 1 or -1
            end
        elseif c1_num ~= nil then -- c1 is numeric, c2 is alphanumeric (numeric is older)
            return -1
        elseif c2_num ~= nil then -- c1 is alphanumeric, c2 is numeric (alphanumeric is older)
            return 1
        else -- Both alphanumeric
            if c1 ~= c2 then
                return c1 > c2 and 1 or -1
            end
        end
    end

    return 0 -- Versions are equal
end

function utils.bit_not(n)
	local p,c=1,0
	while n>0 do
		local r=n%2
		if r<1 then c=c+p end
		n,p=(n-r)/2,p*2
	end
	return c
end

function utils.uint32_to_bytes(n)
	n = n & 0xFFFFFFFF
	local b1 = (n >> 24) & 0xFF
	local b2 = (n >> 16) & 0xFF
	local b3 = (n >> 8) & 0xFF
	local b4 = n & 0xFF

	return {b1, b2, b3, b4}
end

return utils
