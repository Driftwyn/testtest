                            Font = Enum.Font.GothamBold,
                            Text = comp[1],
                            TextColor3 = T().TextDim,
                            TextSize = 11,
                            ZIndex = 401,
                            Parent = popup
                        })

                        local val = New("TextLabel", {
                            AnchorPoint = Vector2.new(1, 0),
                            BackgroundTransparency = 1,
                            Position = UDim2.new(1, -12, 0, y),
                            Size = UDim2.fromOffset(32, 20),
                            Font = Enum.Font.Gotham,
                            Text = tostring(comp[2]),
                            TextColor3 = T().TextDim,
                            TextSize = 10,
                            ZIndex = 401,
                            Parent = popup
                        })

                        local tr = New("Frame", {
                            BackgroundColor3 = T().Surface3,
                            BorderSizePixel = 0,
                            Position = UDim2.fromOffset(37, y + 8),
                            Size = UDim2.new(1, -87, 0, 4),
                            ZIndex = 401,
                            Parent = popup
                        })
                        Corner(tr, 2)

                        local fl = New("Frame", {
                            BackgroundColor3 = comp[3],
                            BorderSizePixel = 0,
                            Size = UDim2.new(comp[2] / 255, 0, 1, 0),
                            ZIndex = 402,
                            Parent = tr
                        })
                        Corner(fl, 2)

                        local dragging = false
                        local function update(x)
                            local ratio = math.clamp((x - tr.AbsolutePosition.X) / math.max(1, tr.AbsoluteSize.X), 0, 1)
                            local n = math.floor(ratio * 255 + 0.5)
                            comp[2] = n
                            val.Text = tostring(n)
                            fl.Size = UDim2.new(ratio, 0, 1, 0)

                            comps[i][2] = n
                            setColor(Color3.fromRGB(comps[1][2], comps[2][2], comps[3][2]), true)
                        end

                        tr.InputBegan:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = true
                                update(input.Position.X)
                            end
                        end)
                        table.insert(popupConnections, UserInputService.InputChanged:Connect(function(input)
                            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                            or input.UserInputType == Enum.UserInputType.Touch) then
                                update(input.Position.X)
                            end
                        end))
                        table.insert(popupConnections, UserInputService.InputEnded:Connect(function(input)
                            if input.UserInputType == Enum.UserInputType.MouseButton1
                            or input.UserInputType == Enum.UserInputType.Touch then
                                dragging = false
                            end
                        end))
                    end
                end)

                ScreenGui.Destroying:Connect(close)

                return {
                    Set = function(_, c) setColor(c, true) end,
                    Get = function() return color end
                }
            end

            table.insert(Tab.Sections, Section)
            Section.AddMultiSelect = Section.AddMultiDropdown
            return Section
        end

        table.insert(Window.Tabs, Tab)

        if #Window.Tabs == 1 then
            selectTab(Tab)
        end

        Tab.CreateSection = Tab.AddSection
        return Tab
    end

    Window.CreateTab = Window.AddTab
    return Window
end

return DriftwynUI
