LoadingTime = 0.05
IdleTime = 0.2
SpinningUnits = 0.1
SpinningTimeUnits = 20
SpinningTimeUnitsOffset = 4
EvaluatingTime = 1


MaxDiamonds = 8 -- Stacks

-- Payouts
TripleBig = 20
TripleSmall = 10
DoubleBig = 4
SingleBig = 1

IconNum = 6
Symbols = {"X", "o", "O", "#", "$", "*"}

State = {Idle = "0", Playing = "1", CashingOut = "2", Spinning = "3", Eval = "4", Loading = "5", OutOfService = "6"}

local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

local state = State.Playing
local spinningCounter = {0, 0, 0}
local wheel = {math.random(IconNum), math.random(IconNum), math.random(IconNum)}
local scoringString = "0fffff0"
local coins = 0
local timerID = 0

-- setState(state) sets the state to the new state and enacts any other required changes
function setState(newState)
  state = newState
  if newState == State.Idle then
    -- TODO check how many coins we have to figure out if we should put ourselves out of service
    -- Check if we are out or full of diamonds
    if turtle.getItemCount(getSlotToDeposit()) > TripleBig and getSlotToDeposit() <= MaxDiamonds then
      print(getSlotToDeposit())
      -- Started Idling, start idle timer
      setTimer(IdleTime)
    else
      setState(State.OutOfService)
    end
  end
  if newState == State.Loading then
    -- Started loading coins into the machine, start Timer
    setTimer(LoadingTime)

  elseif newState == State.Spinning then
    -- Started spinning set our spinningCounter to value and set the wheel to random values
    coins = coins - 1
    spinningCounter = {SpinningTimeUnits, SpinningTimeUnits + SpinningTimeUnitsOffset, SpinningTimeUnits + SpinningTimeUnitsOffset * 2}
    wheel = {math.random(IconNum), math.random(IconNum), math.random(IconNum)}
    updateDisplay()
    -- Set timer to the spinning interval
    setTimer(SpinningUnits)

  elseif newState == State.Eval then
    -- Started evaluating decide how much was won
    -- ############################################# NOTE: Hardcoded wining combos are here
    print(wheel[1] .. wheel[2] .. wheel[3])
    if wheel[1] == 1 and wheel[2] == 1 and wheel[3] == 1 then
      scoringString ="0f111f0"
      coins = coins + TripleBig
      speaker.playSound("entity.player.levelup")
    elseif wheel[1] == wheel[2] and wheel[2] == wheel[3] then
      scoringString ="0f111f0"
      coins = coins + TripleSmall
      speaker.playSound("entity.player.levelup")
    elseif (wheel[1] == 1 and wheel[2] == 1) or (wheel[2] == 1 and wheel[3] == 1) or (wheel[1] == 1 and wheel[3] == 1) then
      if (wheel[1] == 1 and wheel[2] == 1) then
        scoringString ="0f11ff0"
      elseif (wheel[2] == 1 and wheel[3] == 1) then
        scoringString ="0ff11f0"
      elseif (wheel[1] == 1 and wheel[3] == 1) then
        scoringString ="0f1f1f0"
      end
      coins = coins + DoubleBig
      speaker.playSound("entity.experience_orb.pickup")
    elseif wheel[1] == 1 or wheel[2] == 1 or wheel[3] == 1 then
      if wheel[1] == 1 then
        scoringString ="0f1fff0"
      elseif wheel[2] == 1 then
        scoringString ="0ff1ff0"
      elseif wheel[3] == 1 then
        scoringString ="0fff1f0"
      end
      coins = coins + SingleBig
      speaker.playSound("entity.experience_orb.pickup")
    end

    updateDisplay()

    -- If our new coins is greater than the amount of coins we have - the triplebig then cashout and put out of service
    if coins >= (turtle.getItemCount(getSlotToDeposit()) + (getSlotToDeposit() - 1) * 64) - TripleBig then
      setState(State.CashingOut)
    else
      setTimer(EvaluatingTime)
    end

  elseif newState == State.CashingOut then
    setTimer(LoadingTime)

  elseif state == State.OutOfService then
      -- Display out of service
      updateDisplay()
      os.shutdown()
  end
end

-- Stop existing timer and set up new one with updated interval
function setTimer(interval)
  os.cancelTimer(timerID)
  timerrId = os.startTimer(interval)
end

function wheelAdd(index, amount)
  local out = wheel[index] + amount
  while out <= 0 do
    out = out + IconNum
  end
  while out > IconNum do
    out = out - IconNum
  end
  return out
end

function toSymbol(int)
  return Symbols[int]
end

function getSlotToDeposit() 
  local slot = 1
  while slot <= 15 do
    if turtle.getItemCount(slot) < 64 then
      return slot
    end
    slot = slot + 1
  end
  return -1 -- BADDD
end

-- Display the updated information to the screen
function updateDisplay()
  -- Draw Background and title
  mon.setBackgroundColor(colors.green)
  mon.clear()
  mon.setCursorPos(1,1)
  mon.blit(" SLOTS ", "0e15ba0", "ddddddd")
  -- Draw slots
  if state == State.OutOfService then
    mon.setCursorPos(1,2)
    mon.blit("  OUT  ", "fffffff", "0000000")
    mon.setCursorPos(1,3)
    mon.blit("   OF  ", "fffffff", "0000000")
    mon.setCursorPos(1,4)
    mon.blit("SERVICE", "fffffff", "0000000")
  else
    mon.setCursorPos(1,2)
    mon.blit("  " .. toSymbol(wheelAdd(1, -1)) .. toSymbol(wheelAdd(2, -1)) .. toSymbol(wheelAdd(3, -1)) .. "  ", "00fff00", "d00000d")
    mon.setCursorPos(1,3)
    mon.blit(" >" .. toSymbol(wheel[1]) .. toSymbol(wheel[2]) .. toSymbol(wheel[3]) .. "< ", scoringString, "d00000d")
    mon.setCursorPos(1,4)
    mon.blit("  " .. toSymbol(wheelAdd(1, 1)) .. toSymbol(wheelAdd(2, 1)) .. toSymbol(wheelAdd(3, 1)) .. "  ", "00fff00", "d00000d")
  end
  -- Draw the score
  mon.setCursorPos(1,5)
  mon.blit("CO  " .. string.format("%03d", coins), "0000fff", "eeddddd")
end

-- ######################    INITIALIZATION    ######################
math.randomseed(os.time())
turtle.select(16)
setState(State.Idle)
updateDisplay()

-- ######################      MAIN LOOP      ######################
while true do
  local eventData = {os.pullEvent()}
  local event = eventData[1]

  -- Lever Pulled (If playing then go to spinning)
  if event == "redstone" then
    if state == State.Playing then
      setState(State.Spinning)
    end
  end

  -- Monitor Touched
  if event == "monitor_touch" then
    -- Check if cash out button was pressed
    local x = eventData[3]
    local y = eventData[4]
    if x <= 2 and y == 5 then
      if state == State.Playing then
        setState(State.CashingOut)
      elseif state == State.Idle then
        setState(State.Loading)
      end
    end
  end

  -- Timer triggered
  if event == "timer" then
    -- If we are idling check if there is a deposit
    if state == State.Idle then
      setTimer(IdleTime)
    end

    -- If we are loading then check if there is more to load and load
    if state == State.Loading then
      local ret, str = turtle.suck()
      if ret then
        if turtle.getItemDetail()["name"] == "minecraft:diamond" then
          coins = coins + turtle.getItemDetail()["count"]
          while turtle.getItemCount() > 0 do
            turtle.transferTo(getSlotToDeposit())
          end
          updateDisplay()
        else
          turtle.dropDown()
        end
        setTimer(LoadingTime)
      else
        setState(State.Playing)
      end
    end
    -- If we are in spinning then decrement the counter and increment the wheel
    if state == State.Spinning then
      local spinning = false
      if spinningCounter[1] > 0 then
        spinningCounter[1] = spinningCounter[1] - 1
        wheel[1] = wheelAdd(1, 1)
        spinning = true
      end
      if spinningCounter[2] > 0 then
        spinningCounter[2] = spinningCounter[2] - 1
        wheel[2] = wheelAdd(2, 1)
        spinning = true
      end
      if spinningCounter[3] > 0 then
        spinningCounter[3] = spinningCounter[3] - 1
        wheel[3] = wheelAdd(3, 1)
        spinning = true
      end
      -- If we arestill spinning then reset timer
      if spinning then
        if spinningCounter[3] == 0 or spinningCounter[3] == SpinningTimeUnitsOffset or spinningCounter[3] == SpinningTimeUnitsOffset * 2 then
          speaker.playNote("bell", 3)
        end
        if spinningCounter[3] > 0 then
          speaker.playNote("snare")
        end
        updateDisplay()
        setTimer(SpinningUnits)
      else
        -- All counters are at zero
        setState(State.Eval)
      end
    end

    -- If we are evaluating then we should go back to playing if we still have coins
    if state == State.Eval then
      if coins > 0 then
        setState(State.Playing)
      else
        setState(State.Idle)
      end
      scoringString = "0fffff0"
    end

    -- If we are cashing out then ya know cash out
    if state == State.CashingOut then
      local topslot = getSlotToDeposit()
      while coins > 0 do
        print("casshhh")
        turtle.select(topslot)
        local ammountToDrop = math.min(turtle.getItemCount(), coins)
        turtle.drop(ammountToDrop)
        coins = coins - ammountToDrop
        topslot = topslot - 1
        updateDisplay()
      end
      turtle.select(16)
      setState(State.Idle)
    end
  end
end