-- GET TABLE LENGTH
function table.len(tbl, start_count)
    start_count = start_count or 0;
    for i, value in ipairs(tbl) do
        start_count = start_count + 1;
    end; return start_count;
end;