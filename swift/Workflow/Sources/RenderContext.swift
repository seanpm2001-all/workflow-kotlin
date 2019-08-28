/*
 * Copyright 2019 Square Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import ReactiveSwift
import Result

/// `RenderContext` is the composition point for the workflow tree.
///
/// During a render pass, a workflow may want to defer to a child
/// workflow to render some portion of its content. For example,
/// a workflow that renders to a split-screen view model might
/// delegate to child A for the left side, and child B for the right
/// side view models. Nesting allows for a fractal tree that is constructed
/// out of many small parts.
///
/// If a parent wants to delegate to a child workflow, it must first
/// create an instance of that workflow. This can be thought of as the
/// model of the child workflow. It does not contain any active state,
/// it simply contains the data necessary to create or update a workflow
/// node.
///
/// The parent then calls `render(workflow:outputMap:)`
/// with two values:
/// - The child workflow.
/// - A closure that transforms the child's output events into the parent's
///   `Event` type so that the parent can respond to events generated by
///   the child.
///
/// If the parent had previously rendered a child of the same type, the existing
/// child workflow node is updated.
///
/// If the parent had not rendered a child of the same type in the previous
/// render pass, a new child workflow node is generated.
///
/// The infrastructure then performs a render pass on the child to obtain its
/// `Rendering` value, which is then returned to the caller.
public class RenderContext<WorkflowType: Workflow>: RenderContextType {

    private (set) var isValid = true
    
    // Ensure that this class can never be initialized externally
    private init() {}

    /// Creates or updates a child workflow of the given type, performs a render
    /// pass, and returns the result.
    ///
    /// Note that it is a programmer error to render two instances of a given workflow type with the same `key`
    /// during the same render pass.
    ///
    /// - Parameter workflow: The child workflow to be rendered.
    /// - Parameter outputMap: A closure that transforms the child's output type into `Action`.
    /// - Parameter key: A string that uniquely identifies this child.
    ///
    /// - Returns: The `Rendering` result of the child's `render` method.
    public func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where Child : Workflow, Action : WorkflowAction, WorkflowType == Action.WorkflowType {
        fatalError()
    }

    public func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType {
        fatalError()
    }

    public func subscribe<Action>(signal: Signal<Action, NoError>) where Action : WorkflowAction, WorkflowType == Action.WorkflowType {
        fatalError()
    }

    public func awaitResult<W, Action>(for worker: W, outputMap: @escaping (W.Output) -> Action) where W : Worker, Action : WorkflowAction, WorkflowType == Action.WorkflowType {
        fatalError()
    }
    
    final func invalidate() {
        isValid = false
    }
    
    // API to allow custom context implementations to power a render context
    static func make<T: RenderContextType>(implementation: T) -> RenderContext<WorkflowType> where T.WorkflowType == WorkflowType {
        return ConcreteRenderContext(implementation)
    }

    // Private subclass that forwards render calls to a wrapped implementation. This is the only `RenderContext` class
    // that is ever instantiated.
    private final class ConcreteRenderContext<T: RenderContextType>: RenderContext where WorkflowType == T.WorkflowType {

        let implementation: T

        init(_ implementation: T) {
            self.implementation = implementation
            super.init()
        }

        override func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where WorkflowType == Action.WorkflowType, Child : Workflow, Action : WorkflowAction {
            assertStillValid()
            return implementation.render(workflow: workflow, key: key, outputMap: outputMap)
        }

        override func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where WorkflowType == Action.WorkflowType, Action : WorkflowAction {
            return implementation.makeSink(of: actionType)
        }

        override func subscribe<Action>(signal: Signal<Action, NoError>) where WorkflowType == Action.WorkflowType, Action : WorkflowAction {
            assertStillValid()
            return implementation.subscribe(signal: signal)
        }


        override func awaitResult<W, Action>(for worker: W, outputMap: @escaping (W.Output) -> Action) where W : Worker, Action : WorkflowAction, WorkflowType == Action.WorkflowType {
            assertStillValid()
            implementation.awaitResult(for: worker, outputMap: outputMap)
        }
        
        private func assertStillValid() {
            assert(isValid, "A `RenderContext` instance was used outside of the workflow's `render` method. It is a programmer error to capture a context in a closure or otherwise cause it to be used outside of the `render` method.")
        }

    }

}


internal protocol RenderContextType: class {
    associatedtype WorkflowType: Workflow

    func render<Child, Action>(workflow: Child, key: String, outputMap: @escaping (Child.Output) -> Action) -> Child.Rendering where Child: Workflow, Action: WorkflowAction, Action.WorkflowType == WorkflowType

    func makeSink<Action>(of actionType: Action.Type) -> Sink<Action> where Action: WorkflowAction, Action.WorkflowType == WorkflowType

    func subscribe<Action>(signal: Signal<Action, NoError>) where Action: WorkflowAction, Action.WorkflowType == WorkflowType

    func awaitResult<W, Action>(for worker: W, outputMap: @escaping (W.Output) -> Action) where W: Worker, Action: WorkflowAction, Action.WorkflowType == WorkflowType
    
}


extension RenderContext {

    public func makeSink<Event>(of eventType: Event.Type, onEvent: @escaping (Event, inout WorkflowType.State) -> WorkflowType.Output?) -> Sink<Event> {
        return makeSink(of: AnyWorkflowAction.self)
            .contraMap { event in
                return AnyWorkflowAction<WorkflowType> { state in
                    return onEvent(event, &state)
                }
            }
    }

}

extension RenderContext {

    public func awaitResult<W>(for worker: W) where W : Worker, W.Output : WorkflowAction, WorkflowType == W.Output.WorkflowType {
        awaitResult(for: worker, outputMap: { $0 })
    }

    public func awaitResult<W>(for worker: W, onOutput: @escaping (W.Output, inout WorkflowType.State) -> WorkflowType.Output?) where W: Worker {
        awaitResult(for: worker) { output in
            return AnyWorkflowAction<WorkflowType> { state in
                return onOutput(output, &state)
            }
        }
    }

}
