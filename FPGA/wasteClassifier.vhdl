library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TrashClassifierFSM is
    Port (
        clk       : in  STD_LOGIC;
        rst       : in  STD_LOGIC;
        strobe    : in  STD_LOGIC; -- Сигнал от MCP: данные готовы
        feature_1 : in  UNSIGNED(7 downto 0); -- Например, соотношение сторон
        feature_2 : in  UNSIGNED(7 downto 0); -- Например, цветовой маркер
        class_out : out UNSIGNED(3 downto 0); -- Результат для Prolog
        ready     : out STD_LOGIC
    );
end TrashClassifierFSM;

architecture Behavioral of TrashClassifierFSM is
    type state_type is (IDLE, READ_DATA, PROCESS_LOGIC, SEND_RESULT);
    signal current_state, next_state : state_type;
    signal internal_class : UNSIGNED(3 downto 0) := "0000";
begin

    -- Синхронный процесс сброса и смены состояний
    state_register: process(clk, rst)
    begin
        if rst = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Комбинационная логика автомата
    next_state_logic: process(current_state, strobe, feature_1, feature_2)
    begin
        next_state <= current_state;
        ready <= '0';

        case current_state is
            when IDLE =>
                if strobe = '1' then
                    next_state <= READ_DATA;
                end if;
                
            when READ_DATA =>
                next_state <= PROCESS_LOGIC;
                
            when PROCESS_LOGIC =>
                -- Автоматная логика фильтрации вместо ИИ
                if (feature_1 > 40 and feature_1 < 120) and feature_2 = 25 then 
                    internal_class <= "0001"; -- Подозрение на конфетную этикетку (Класс 1)
                else
                    internal_class <= "0000"; -- Неизвестный объект
                end if;
                next_state <= SEND_RESULT;
                
            when SEND_RESULT =>
                ready <= '1';
                next_state <= IDLE;
        end case;
    end process;

    class_out <= internal_class;

end Behavioral;
