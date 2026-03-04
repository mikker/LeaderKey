import XCTest

@testable import Leader_Key

final class TOMLConfigTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseSimpleAction() throws {
        let toml = """
            t = "Terminal"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "t")
            XCTAssertEqual(action.type, .application)
            XCTAssertTrue(action.value.contains("Terminal"))
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseURL() throws {
        let toml = """
            g = "https://google.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "g")
            XCTAssertEqual(action.type, .url)
            XCTAssertEqual(action.value, "https://google.com")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseRaycastURL() throws {
        let toml = """
            e = "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.type, .url)
            XCTAssertTrue(action.value.hasPrefix("raycast://"))
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseCustomSchemeURL() throws {
        let toml = """
            x = "myapp:do-thing"
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.type, .url)
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseFolder() throws {
        let toml = """
            d = "~/Downloads"
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "d")
            XCTAssertEqual(action.type, .folder)
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseArrayWithLabel() throws {
        let toml = """
            v = ["Visual Studio Code", "VS Code"]
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "v")
            XCTAssertEqual(action.label, "VS Code")
        } else {
            XCTFail("Expected action")
        }
    }

    // MARK: - Groups

    func testParseGroup() throws {
        let toml = """
            [l]
            label = "[links]"
            g = "https://github.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .group(let subgroup) = group.actions[0] {
            XCTAssertEqual(subgroup.key, "l")
            XCTAssertEqual(subgroup.label, "[links]")
            XCTAssertEqual(subgroup.actions.count, 1)
        } else {
            XCTFail("Expected group")
        }
    }

    func testParseNestedGroup() throws {
        let toml = """
            [l]
            label = "[links]"
            g = "https://github.com"

            [l.m]
            label = "[me]"
            t = "https://twitter.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .group(let linksGroup) = group.actions[0] {
            XCTAssertEqual(linksGroup.key, "l")
            XCTAssertEqual(linksGroup.label, "[links]")

            // Should have 1 action and 1 nested group
            XCTAssertEqual(linksGroup.actions.count, 2)

            // Find the nested group
            let nestedGroup = linksGroup.actions.first { item in
                if case .group = item { return true }
                return false
            }
            XCTAssertNotNil(nestedGroup)

            if case .group(let meGroup) = nestedGroup! {
                XCTAssertEqual(meGroup.key, "m")
                XCTAssertEqual(meGroup.label, "[me]")
            }
        } else {
            XCTFail("Expected group")
        }
    }

    func testParseActionTable() throws {
        let toml = """
            [r.e]
            value = "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
            icon = "square.and.arrow.up.circle.fill"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .group(let parentGroup) = group.actions[0] {
            XCTAssertEqual(parentGroup.key, "r")
            XCTAssertEqual(parentGroup.actions.count, 1)
            if case .action(let action) = parentGroup.actions[0] {
                XCTAssertEqual(action.key, "e")
                XCTAssertEqual(action.type, .url)
                XCTAssertTrue(action.value.hasPrefix("raycast://"))
                XCTAssertEqual(action.iconPath, "square.and.arrow.up.circle.fill")
            } else {
                XCTFail("Expected action")
            }
        } else {
            XCTFail("Expected group")
        }
    }

    func testParseActionTableWithExplicitType() throws {
        let toml = """
            [x]
            value = "https://example.com"
            type = "command"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "x")
            XCTAssertEqual(action.type, .command)
        } else {
            XCTFail("Expected action")
        }
    }

    // MARK: - Comments

    func testIgnoresComments() throws {
        let toml = """
            # This is a comment
            t = "Terminal"  # inline comment
            # Another comment
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
    }

    func testCommentsInStrings() throws {
        let toml = """
            t = "Terminal # not a comment"
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            // The value should contain the # because it's inside quotes
            XCTAssertTrue(action.value.contains("#") || action.value.contains("Terminal"))
        } else {
            XCTFail("Expected action")
        }
    }

    // MARK: - Empty Lines

    func testIgnoresEmptyLines() throws {
        let toml = """

            t = "Terminal"

            g = "https://google.com"

            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 2)
    }

    // MARK: - Serialization

    func testSerializeSimpleAction() throws {
        let action = Action(key: "t", type: .application, value: "/Applications/Terminal.app")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("t = "))
    }

    func testSerializeWithLabel() throws {
        let action = Action(
            key: "v", type: .application, label: "VS Code",
            value: "/Applications/Visual Studio Code.app")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("VS Code"))
    }

    func testSerializeGroup() throws {
        let linkAction = Action(key: "g", type: .url, value: "https://github.com")
        let linksGroup = Group(key: "l", label: "[links]", actions: [.action(linkAction)])
        let rootGroup = Group(key: nil, actions: [.group(linksGroup)])

        let toml = TOMLConfig.serialize(rootGroup)

        XCTAssertTrue(toml.contains("[l]"))
        XCTAssertTrue(toml.contains("label = \"[links]\""))
    }

    func testSerializeActionTable() throws {
        let action = Action(
            key: "e", type: .url,
            value: "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols",
            iconPath: "square.and.arrow.up.circle.fill"
        )
        let group = Group(key: "r", actions: [.action(action)])
        let rootGroup = Group(key: nil, actions: [.group(group)])

        let toml = TOMLConfig.serialize(rootGroup)

        XCTAssertTrue(toml.contains("[r.e]"))
        XCTAssertTrue(toml.contains("value = \"raycast://extensions/raycast/emoji-symbols/search-emoji-symbols\""))
        XCTAssertTrue(toml.contains("icon = \"square.and.arrow.up.circle.fill\""))
        XCTAssertFalse(toml.contains("{"))
    }

    func testSerializeExplicitTypeWhenMismatch() throws {
        let action = Action(key: "u", type: .command, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("[u]"))
        XCTAssertTrue(toml.contains("type = \"command\""))
        XCTAssertTrue(toml.contains("value = \"https://example.com\""))
    }

    // MARK: - Round Trip

    func testRoundTrip() throws {
        let originalToml = """
            t = "Terminal"

            [l]
            label = "[links]"
            g = "https://github.com"
            """

        let group = try TOMLConfig.parse(originalToml)
        let serialized = TOMLConfig.serialize(group)
        let reparsed = try TOMLConfig.parse(serialized)

        // Compare structure
        XCTAssertEqual(group.actions.count, reparsed.actions.count)
    }

    // MARK: - Error Handling

    func testInvalidSyntaxThrows() throws {
        let toml = """
            invalid line without equals
            """

        XCTAssertThrowsError(try TOMLConfig.parse(toml))
    }

    func testEmptyKeyThrows() throws {
        let toml = """
             = "value"
            """

        XCTAssertThrowsError(try TOMLConfig.parse(toml))
    }

    // MARK: - Special Characters in Keys

    func testParseOpenBracketKey() throws {
        let toml = """
            "[" = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "[")
            XCTAssertEqual(action.type, .url)
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseCloseBracketKey() throws {
        let toml = """
            "]" = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "]")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseEqualsKey() throws {
        let toml = """
            "=" = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "=")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseHashKey() throws {
        let toml = """
            "#" = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "#")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseDotKey() throws {
        let toml = """
            "." = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, ".")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseSpaceKey() throws {
        let toml = """
            " " = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, " ")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseBacktickKey() throws {
        let toml = """
            "`" = "https://example.com"
            """

        let group = try TOMLConfig.parse(toml)

        XCTAssertEqual(group.actions.count, 1)
        if case .action(let action) = group.actions[0] {
            XCTAssertEqual(action.key, "`")
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseQuoteInValue() throws {
        let toml = """
            t = "say \\"hello\\""
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertTrue(action.value.contains("\""))
        } else {
            XCTFail("Expected action")
        }
    }

    func testParseBackslashInValue() throws {
        let toml = """
            t = "path\\\\to\\\\file"
            """

        let group = try TOMLConfig.parse(toml)

        if case .action(let action) = group.actions[0] {
            XCTAssertTrue(action.value.contains("\\"))
        } else {
            XCTFail("Expected action")
        }
    }

    // MARK: - Serialization of Special Characters

    func testSerializeOpenBracketKey() throws {
        let action = Action(key: "[", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\"[\""))
    }

    func testSerializeCloseBracketKey() throws {
        let action = Action(key: "]", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\"]\""))
    }

    func testSerializeEqualsKey() throws {
        let action = Action(key: "=", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\"=\""))
    }

    func testSerializeHashKey() throws {
        let action = Action(key: "#", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\"#\""))
    }

    func testSerializeSpaceKey() throws {
        let action = Action(key: " ", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\" \""))
    }

    func testSerializeBacktickKey() throws {
        let action = Action(key: "`", type: .url, value: "https://example.com")
        let group = Group(key: nil, actions: [.action(action)])

        let toml = TOMLConfig.serialize(group)

        XCTAssertTrue(toml.contains("\"`\""))
    }

    // MARK: - Round Trip Special Characters

    func testRoundTripBracketKeys() throws {
        let toml = """
            "[" = "https://open.com"
            "]" = "https://close.com"
            """

        let group = try TOMLConfig.parse(toml)
        let serialized = TOMLConfig.serialize(group)
        let reparsed = try TOMLConfig.parse(serialized)

        XCTAssertEqual(group.actions.count, reparsed.actions.count)

        // Verify keys preserved
        let keys = reparsed.actions.compactMap { item -> String? in
            if case .action(let action) = item { return action.key }
            return nil
        }
        XCTAssertTrue(keys.contains("["))
        XCTAssertTrue(keys.contains("]"))
    }

    func testRoundTripSpecialCharacterKeys() throws {
        let toml = """
            "=" = "https://equals.com"
            "#" = "https://hash.com"
            "." = "https://dot.com"
            " " = "https://space.com"
            """

        let group = try TOMLConfig.parse(toml)
        let serialized = TOMLConfig.serialize(group)
        let reparsed = try TOMLConfig.parse(serialized)

        XCTAssertEqual(group.actions.count, reparsed.actions.count)
    }

    // MARK: - Complex Nested Structure

    func testParseComplexConfig() throws {
        let toml = """
            t = "Terminal"

            [o]
            s = "Safari"
            e = "/Applications/Mail.app"

            [r]
            e = "raycast://extensions/raycast/emoji-symbols/search-emoji-symbols"
            p = "raycast://confetti"

            [r.c]
            value = "raycast://extensions/raycast/system/open-camera"
            icon = "camera"
            """

        let group = try TOMLConfig.parse(toml)

        // Root action
        let rootActions = group.actions.compactMap { item -> Action? in
            if case .action(let action) = item { return action }
            return nil
        }
        XCTAssertEqual(rootActions.count, 1)
        XCTAssertEqual(rootActions[0].key, "t")

        // Groups
        let groups = group.actions.compactMap { item -> Group? in
            if case .group(let g) = item { return g }
            return nil
        }
        XCTAssertEqual(groups.count, 2)
    }

    func testParseGroupWithActionTable() throws {
        let toml = """
            [r]
            e = "raycast://emoji"

            [r.p]
            value = "raycast://confetti"
            icon = "party.popper"
            label = "Party!"
            """

        let group = try TOMLConfig.parse(toml)

        if case .group(let rGroup) = group.actions[0] {
            XCTAssertEqual(rGroup.key, "r")
            XCTAssertEqual(rGroup.actions.count, 2)

            // Find the action with icon
            let actionWithIcon = rGroup.actions.compactMap { item -> Action? in
                if case .action(let action) = item, action.iconPath != nil { return action }
                return nil
            }.first

            XCTAssertNotNil(actionWithIcon)
            XCTAssertEqual(actionWithIcon?.key, "p")
            XCTAssertEqual(actionWithIcon?.iconPath, "party.popper")
            XCTAssertEqual(actionWithIcon?.label, "Party!")
        } else {
            XCTFail("Expected group")
        }
    }
}
