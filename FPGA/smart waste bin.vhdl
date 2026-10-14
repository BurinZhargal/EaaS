library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity RobotBinHardwareCore is
    Generic (
        MAX_TRASH_LIMIT : unsigned(7 downto 0) := x"64" -- Лимит 100 единиц мусора
    );
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        kick_sensor   : in  STD_LOGIC; -- Датчик удара корпуса
        opencv_pulse  : in  STD_LOGIC; -- Импульс от Dart/OpenCV при детекции
        
        system_active : out STD_LOGIC; -- Сигнал активации (на MCP Dart)
        bin_full      : out STD_LOGIC; -- Флаг заполнения (на Delphi AI)
        trash_count   : out STD_LOGIC_VECTOR(7 downto 0)
    );
end RobotBinHardwareCore;

architecture Behavioral of RobotBinHardwareCore is
    -- Внутренние триггеры
    signal jk_active_q : STD_LOGIC := '0';
    signal jk_full_q   : STD_LOGIC := '0';
    
    -- Сумматор / Счетчик
    signal current_count : unsigned(7 downto 0) := (others => '0');
    signal is_overlimit  : STD_LOGIC := '0';
begin

    -- 1. JK-Триггер режима активации по пинку (работает как T-триггер)
    process(kick_sensor, rst)
    begin
        if rst = '1' then
            jk_active_q <= '0';
        elsif rising_edge(kick_sensor) then
            jk_active_q <= not jk_active_q; -- Переключение состояния Awake/Sleep
        end if;
    end process;

    -- 2. Сумматор (Счетчик мусора) по импульсам от OpenCV
    process(clk, rst)
    begin
        if rst = '1' then
            current_count <= (others => '0');
        elsif rising_edge(clk) then
            if opencv_pulse = '1' and jk_active_q = '1' then
                current_count <= current_count + 1; -- Использование сумматора
            end if;
        end if;
    end process;

    -- Комбинаторный компаратор лимита
    is_overlimit <= '1' when (current_count >= MAX_TRASH_LIMIT) else '0';

    -- 3. JK-Триггер флага заполнения бака
    process(clk, rst)
    begin
        if rst = '1' then
            jk_full_q <= '0';
        elsif rising_edge(clk) then
            -- Логика JK: J=is_overlimit, K=rst (обработан выше)
            if is_overlimit = '1' then
                jk_full_q <= '1'; -- Выставляем флаг «Заполнено»
            end if;
        end if;
    end process;

    -- Выходы на внешнюю систему (MCP / Драйверы)
    system_active <= jk_active_q;
    bin_full      <= jk_full_q;
    trash_count   <= std_logic_vector(current_count);

end Behavioral;
