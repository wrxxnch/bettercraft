-- TEXT TO NAME
function string.to_name(str, cap, sep, i, result)
    result = result or ""; i = 1; cap = cap or 1;
    sep = sep or ""; str = string.gsub(str, "_", " ");
    for part in string.gmatch(str, "([^".." ".."]+)") do
        if (i > 1) then sep = " "; end
        if (cap == 1) then
            result = result..sep..part:gsub("^%l", string.upper);
        else
            result = result..sep..part;
        end
    end
    return result;
end